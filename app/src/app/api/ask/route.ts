import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  counterparties: {
    match: /counterpart|buyer|late|overdue|worst|highest|exposure/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, SETTLEMENTS_DUE, SETTLEMENTS_LATE, LATEST_DAYS_OVERDUE,
       ROUND(ON_TIME_RATE_PCT, 1) AS ON_TIME_RATE_PCT, ROUND(LATEST_EXPOSURE_USD / 1e6, 2) AS OPEN_EXPOSURE_USD_M
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY LATEST_DAYS_OVERDUE DESC) <= 3
ORDER BY LATEST_DAYS_OVERDUE DESC, SETTLEMENTS_LATE DESC, ENTITY_ID`,
  },
  products: {
    match: /product|grade|cpo|crude|olein|stearin|kernel|pko|pfad|why/i,
    sql: `SELECT PRODUCT, COUNTERPARTY_COUNT, SETTLEMENTS_DUE, SETTLEMENTS_LATE, ROUND(ON_TIME_RATE_PCT, 1) AS ON_TIME_RATE_PCT,
       ROUND(OPEN_EXPOSURE_USD / 1e6, 2) AS OPEN_EXPOSURE_USD_M, ROUND(OVERDUE30_PCT, 1) AS OVERDUE30_PCT
FROM CURATED.PRODUCT_SUMMARY ORDER BY SETTLEMENTS_LATE DESC`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'On-time settlement rate = settlements paid on time / settlements due. Exposure >30d overdue = share of open contract exposure on buyers more than 30 days overdue, on the latest day. ' +
  'Payment commitment rate = payment commitments / credit-desk follow-ups. Amounts are in US dollars (USD). ' +
  'All buyers, prices and amounts are synthetic demo data. Do not give price views or trading advice.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a trade-credit analyst on a palm oil trading desk. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, counterparties, products, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.counterparties.sql),
        executeQuery(INTENTS.products.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(LATE_PROB_14D, 2) AS LATE_PROB_14D, RISK_BAND
FROM ML.LATE_RISK_SCORES ORDER BY LATE_PROB_14D DESC, ENTITY_ID LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS COUNTERPARTIES FROM ML.LATE_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, mostOverdueCounterparties: counterparties, products, top5ByRisk: risk, counterpartiesPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for the Head of Trade Credit with 3 prioritised settlement follow-up and credit actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
