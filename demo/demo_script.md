# CPO Trading Analytics

**Indonesia - Palm Oil & Agriculture**
Use case: Commodity Trading Analytics

> Real-time CPO trading intelligence for Indonesia's US$28B palm oil export market — ML.FORECAST projects price movements, Dynamic Tables build position books, and Cortex AI generates market commentary.

## Why Snowflake

Snowflake unifies trading, logistics, and market data — Dynamic Tables maintain real-time position books, ML.FORECAST projects CPO price curves, and Cortex AI synthesizes market intelligence from 300+ trade documents

- **ML.FORECAST on CPO forward curve** - Only demo using ML.FORECAST for palm oil commodity price prediction
- **Real-time position book via Dynamic Tables** - Only demo maintaining live trading positions with mark-to-market in Snowflake
- **Export levy impact calculation** - Indonesia-specific export levy modeling unique to palm oil commodity trading
- **Indonesian CPO trading context** - US$28.5B export market with BMD futures, Belawan FOB, and Rupiah economics
- **300 trade documents searchable** - Cortex Search on contracts, LCs, and market reports for trading intelligence

## What is deployed

| | |
|---|---|
| Database | `ID_PALM_OIL_TRADING` |
| Service | `ID_PALM_OIL_TRADING_APP` |
| Compute pool | `SEA_DEMOS_INDONESIA_POOL` |
| Dimension table | `RAW.EXPORT_LEVY` (20 rows) |
| Fact table | `RAW.MARKET_PRICES` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | IDR (Rp) |

Regions in play: Jakarta, North Sumatra, Riau, East Kalimantan, Sulawesi
Segments: CPO Spot, CPO Forward, Palm Kernel Oil, Refined Products

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh ID_PALM_OIL_TRADING
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| CPO Price | `Rp 14,200/kg` | average per event |
| Export Volume (MTD) | `2.4M MT` | total across Export Levy |
| DMO Compliance | `100%` | average per event |
| Active Contracts | `347` | total across Export Levy |
| Rotterdam CIF | `$892/MT` | average per event |
| India Import Duty | `7.5%` | average per event |
| B35 Mandate Impact | `+1.2M MT` | total across Export Levy |


## Demo flow

1. Trading Desk
2. Price Analytics
3. Logistics & Risk
4. Ask AI
5. Architecture & Data

## Talking points

- **15,000 trades** - physical and derivative across CPO/PKO markets
- **45,000t net long** - CPO position across Q1-Q2 delivery months
- **Rp 23B** - mark-to-market gain on current positions
- **200,000 prices** - market data points (futures, physical, basis)
- **Rp 8.7B VaR** - value-at-risk at 95% confidence
- **300 documents** - trade contracts and market reports searchable

## Business impact

- Indonesia exported US$28.5B in palm oil products in 2023 — world's largest exporter (BPS Indonesia)
- CPO price volatility averaged 25% annualized in 2023 — highest in 5 years (BMD/Bursa Malaysia)
- Indonesian export levy changes can swing margins by 3-5% within a week (GAPKI)
- Real-time position management reduces trading losses by 15-20% vs end-of-day reporting (McKinsey Commodities)

---
Generated from `generator/demo_specs/aws-indonesia-palm-oil-trading.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-indonesia-palm-oil-trading` instead.
