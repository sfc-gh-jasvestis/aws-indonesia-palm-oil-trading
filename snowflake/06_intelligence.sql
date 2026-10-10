-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live late-settlement alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_SETTLEMENTS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic settlement knowledge base (clearly synthetic SOPs) ----------
-- One internal playbook per product and overdue stage. These are fictional
-- trading-desk procedures, not statements of regulation or market practice.
CREATE OR REPLACE TABLE SEARCH.SETTLEMENT_DOCS AS
WITH products AS (SELECT DISTINCT CATEGORY FROM RAW.COUNTERPARTIES),
stages AS (
  SELECT * FROM VALUES (1, '1-7 days overdue'), (2, '8-30 days overdue'), (3, '31+ days overdue') AS s(STAGE_ORDER, OVERDUE_BUCKET)
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.CATEGORY, s.STAGE_ORDER)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  p.CATEGORY,
  s.OVERDUE_BUCKET,
  p.CATEGORY || ' - ' || s.OVERDUE_BUCKET || ' settlement playbook' AS TITLE,
  'Synthetic demo SOP for a fictional palm oil trading desk. Product: ' || p.CATEGORY || '. Stage: ' || s.OVERDUE_BUCKET || '. '
  || 'Step 1: confirm the invoice is unsettled in the trade ledger and that no payment is in transit by bank transfer or letter-of-credit drawing. '
  || 'Step 2: ' || CASE s.STAGE_ORDER
       WHEN 1 THEN 'email the buyer''s treasury contact with the invoice number, cargo reference and amount due, and ask the trader who owns the account for any known reason for the delay.'
       WHEN 2 THEN 'hold a credit-desk call with the buyer, record the reason for the delay (document discrepancy, vessel delay, funding gap, quality claim) and agree a payment-commitment date within 7 days.'
       ELSE 'escalate to the head of credit, pause new cargo nominations for the buyer, review the counterparty''s 14-day late-settlement risk score and LC headroom trend, and prepare a letter-of-credit claim review for credit-committee approval.'
     END
  || ' Step 3: ' || CASE p.CATEGORY
       WHEN 'Crude Palm Oil' THEN 'check the certificate of analysis against the contract grade; a free fatty acid or moisture dispute must go to the quality team before any further chasing.'
       WHEN 'RBD Palm Olein' THEN 'confirm the bill of lading was released to the buyer''s bank; a missing original often explains a late payment.'
       WHEN 'Palm Kernel Oil' THEN 'check the letter-of-credit expiry and remaining amount before agreeing any new payment date.'
       WHEN 'RBD Palm Stearin' THEN 'compare the surveyor weight report with the invoiced tonnage; settle weight differences before escalating.'
       ELSE 'confirm the certificate of origin was issued and sent; buyers may hold payment until it arrives.'
     END
  || ' Step 4: log every follow-up with channel and outcome. Contact only the named treasury and trading contacts of the buyer.' AS CONTENT
FROM products p CROSS JOIN stages s;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.SETTLEMENT_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, OVERDUE_BUCKET
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, OVERDUE_BUCKET, CONTENT FROM SEARCH.SETTLEMENT_DOCS);

-- ---------- Letter-of-credit headroom anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.LC_HEADROOM_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, (LC_HEADROOM_USD / 1000)::FLOAT AS HEADROOM_K_USD
FROM RAW.SETTLEMENT_DAILY;
CREATE OR REPLACE VIEW ML.LC_HEADROOM_TRAIN AS
SELECT * FROM ML.LC_HEADROOM_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.LC_HEADROOM_SERIES);
CREATE OR REPLACE VIEW ML.LC_HEADROOM_DETECT AS
SELECT * FROM ML.LC_HEADROOM_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.LC_HEADROOM_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.LC_HEADROOM_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.LC_HEADROOM_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'HEADROOM_K_USD',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.LC_HEADROOM_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS HEADROOM_K_USD, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.LC_HEADROOM_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.LC_HEADROOM_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'HEADROOM_K_USD'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.TRADING_DESK_ANALYTICS
  TABLES (
    counterparties AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per counterparty, 90-day settlement totals and latest days overdue',
    risk AS ML.LATE_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-14-day late-settlement probability per counterparty',
    products AS CURATED.PRODUCT_SUMMARY PRIMARY KEY (PRODUCT)
      COMMENT = 'Settlements due, late settlements, open exposure and share overdue more than 30 days, by palm oil product',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Portfolio-wide totals per day'
  )
  RELATIONSHIPS (risk_counterparty AS risk (ENTITY_ID) REFERENCES counterparties)
  FACTS (
    counterparties.due_f AS SETTLEMENTS_DUE,
    counterparties.late_f AS SETTLEMENTS_LATE,
    counterparties.settled_usd_f AS INVOICE_SETTLED_USD,
    counterparties.contacts_f AS CREDIT_FOLLOWUPS,
    counterparties.ptp_f AS PAYMENT_COMMITMENTS,
    counterparties.exposure_f AS LATEST_EXPOSURE_USD,
    counterparties.overdue_f AS LATEST_DAYS_OVERDUE,
    counterparties.score_f AS CREDIT_SCORE,
    risk.late_prob_f AS LATE_PROB_14D,
    products.product_due_f AS SETTLEMENTS_DUE,
    products.product_late_f AS SETTLEMENTS_LATE,
    products.product_exposure_f AS OPEN_EXPOSURE_USD,
    products.product_overdue30_f AS OVERDUE30_PCT,
    daily.day_due_f AS SETTLEMENTS_DUE,
    daily.day_late_f AS SETTLEMENTS_LATE,
    daily.day_30overdue_f AS COUNTERPARTIES_30D_OVERDUE
  )
  DIMENSIONS (
    counterparties.counterparty_id AS ENTITY_ID WITH SYNONYMS = ('counterparty', 'buyer', 'buyer id', 'entity'),
    counterparties.counterparty_name AS ENTITY_NAME,
    counterparties.city AS REGION WITH SYNONYMS = ('city', 'region', 'area') COMMENT = 'Indonesian port city that serves the buyer account',
    counterparties.product AS CATEGORY WITH SYNONYMS = ('palm oil product', 'product', 'grade'),
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    products.product_name AS PRODUCT WITH SYNONYMS = ('product grade'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    counterparties.num_counterparties AS COUNT(counterparties.counterparty_id)
      WITH SYNONYMS = ('entities', 'number of counterparties', 'counterparty count', 'how many counterparties', 'number of buyers', 'how many buyers'),
    counterparties.on_time_settlement_rate_pct AS 100 * (SUM(counterparties.due_f) - SUM(counterparties.late_f)) / NULLIF(SUM(counterparties.due_f), 0)
      COMMENT = 'Settlements paid on time / settlements due',
    counterparties.total_settlements_due AS SUM(counterparties.due_f) WITH SYNONYMS = ('settlements due', 'invoices due'),
    counterparties.total_late_settlements AS SUM(counterparties.late_f) WITH SYNONYMS = ('late payments', 'late settlements'),
    counterparties.total_settled_usd AS SUM(counterparties.settled_usd_f) WITH SYNONYMS = ('invoices settled', 'cash received'),
    counterparties.total_exposure_usd AS SUM(counterparties.exposure_f) WITH SYNONYMS = ('open exposure', 'receivables', 'credit exposure'),
    counterparties.payment_commitment_rate_pct AS 100 * SUM(counterparties.ptp_f) / NULLIF(SUM(counterparties.contacts_f), 0)
      COMMENT = 'Payment commitments / credit-desk follow-ups',
    counterparties.avg_credit_score AS AVG(counterparties.score_f),
    counterparties.max_days_overdue AS MAX(counterparties.overdue_f),
    risk.avg_late_prob AS AVG(risk.late_prob_f),
    products.product_settlements_due AS SUM(products.product_due_f),
    products.product_late_settlements AS SUM(products.product_late_f),
    products.product_exposure_usd AS SUM(products.product_exposure_f),
    products.product_overdue30_pct AS AVG(products.product_overdue30_f) COMMENT = 'Share of open exposure more than 30 days overdue, per product',
    daily.daily_settlements_due AS SUM(daily.day_due_f),
    daily.daily_late_settlements AS SUM(daily.day_late_f),
    daily.daily_counterparties_30d_overdue AS SUM(daily.day_30overdue_f)
  )
  COMMENT = 'Synthetic Indonesian palm oil trading analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.CREDIT_DESK_AGENT
  COMMENT = 'Credit-desk assistant over a synthetic Indonesian palm oil trading desk'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give counterparty IDs and numbers with units (USD, %). Never give price views or trading advice."
  orchestration: "Use settlement_analyst for buyers, settlements due, late settlements, on-time settlement rate, open exposure, share overdue more than 30 days, payment commitments, palm oil products, port cities and risk. Use sop_search for settlement follow-up procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: settlement_analyst
      description: "Buyers, settlements due and late, on-time settlement rate, open exposure (USD), share overdue more than 30 days, payment-commitment rate, palm oil products, port cities and 14-day late-settlement risk scores"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic settlement follow-up playbooks by palm oil product and overdue stage"
tool_resources:
  settlement_analyst:
    semantic_view: __DEMO_DB__.APP.TRADING_DESK_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.SETTLEMENT_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live late-settlement alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), COUNTERPARTY_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_USD FLOAT, DAYS_OVERDUE NUMBER, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION ID_PALM_OIL_TRADING_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (COUNTERPARTY_ID, EVENT_TS, AMOUNT_USD, DAYS_OVERDUE, SOP_HINT)
    SELECT t.COUNTERPARTY_ID, t.EVENT_TS, t.AMOUNT_USD, t.DAYS_OVERDUE,
           'Check ' || b.CATEGORY || ' ' || CASE WHEN t.DAYS_OVERDUE <= 7 THEN '1-7 days overdue'
                                                  WHEN t.DAYS_OVERDUE <= 30 THEN '8-30 days overdue' ELSE '31+ days overdue' END
           || ' playbook; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_SETTLEMENTS t
    JOIN RAW.COUNTERPARTIES b ON b.ID = t.COUNTERPARTY_ID
    LEFT JOIN ML.LATE_RISK_SCORES r ON r.ENTITY_ID = t.COUNTERPARTY_ID
    WHERE t.STATUS = 'LATE'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.COUNTERPARTY_ID = t.COUNTERPARTY_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('ID_PALM_OIL_TRADING_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Late settlement alert',
      'New late settlements logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_SETTLEMENT_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_SETTLEMENTS t
    WHERE t.STATUS = 'LATE'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.COUNTERPARTY_ID = t.COUNTERPARTY_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.PRODUCT_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.LATE_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.SETTLEMENT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.LATE_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'CREDIT_SCORE', CREDIT_SCORE, 'MONTHS_TRADING', MONTHS_TRADING,
             'DAYS_OVERDUE', DAYS_OVERDUE, 'HEADROOM_7D_VS_30D', HEADROOM_7D_VS_30D,
             'VESSEL_NOMINATIONS_7D', VESSEL_NOMINATIONS_7D, 'LATE_30D', LATE_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:LATE::FLOAT, 4) AS LATE_PROB_14D,
         CASE WHEN PRED:probability:LATE::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:LATE::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
