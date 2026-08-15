# Demo Script: CPO Trading Analytics
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake unifies trading, logistics, and market data — Dynamic Tables maintain real-time position books, ML.FORECAST projects CPO price curves, and Cortex AI synthesizes market intelligence from 300+ trade documents"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Harianto Gunawan** | Head of Trading | React App (SPCS) | Position exposure, price risk, hedging effectiveness, counterparty limits, export levy impact |
| **Linda Tanjung** | Risk Analyst | Amazon QuickSight | VaR calculation, basis risk, logistics costs, shipping delays, market volatility |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 6 tables | TRADES (15000), POSITIONS (5000), MARKET_PRICES (200000), LOGISTICS (10000), TRADE_DOCS (300), EXPORT_LEVY (100) |
| **CURATED** | 4 Dynamic Tables | POSITION_BOOK, FORWARD_CURVE, LOGISTICS_STATUS, LEVY_IMPACT |
| **ML** | ML.FORECAST | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_EXTRACT, SUMMARIZE | Classification + extraction |
| **Search** | Cortex Search | 300 documents indexed |
| **Agent** | TRADING_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

An Indonesian palm oil trading house manages US$2.8 billion in annual turnover across physical and derivative CPO/PKO markets. With 15,000 trades, fluctuating export levies, and vessels queuing at Belawan, the Head of Trading needs real-time position visibility and AI-generated market intelligence — not end-of-day spreadsheet reports.

---

## Script

### [0:00–0:45] TRADING DESK

**Show**: Trading Desk tab

> "Net long 45,000 tonnes CPO across Q1-Q2 delivery — mark-to-market gain of Rp 23 billion."

**Action**: Point at net position and MTM KPI

### [0:45–1:30] PRICE ANALYTICS

**Show**: Price Analytics tab

> "BMD CPO futures in backwardation — prompt month at MYR 4,200 vs Q3 at MYR 3,950."

**Action**: Show forward curve chart with ML forecast overlay

### [1:30–2:15] LOGISTICS & RISK

**Show**: Logistics & Risk tab

> "Three vessels delayed at Belawan Port — total exposure 12,000 tonnes, demurrage accruing."

**Action**: Show vessel tracker with delay flags

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Harianto asks: 'What's our net CPO position and mark-to-market?'"

**Action**: Type position question

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Six Snowflake capabilities, six AWS services in the dual-build architecture."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST on CPO forward curve** — Only demo using ML.FORECAST for palm oil commodity price prediction
2. **Real-time position book via Dynamic Tables** — Only demo maintaining live trading positions with mark-to-market in Snowflake
3. **Export levy impact calculation** — Indonesia-specific export levy modeling unique to palm oil commodity trading
4. **Indonesian CPO trading context** — US$28.5B export market with BMD futures, Belawan FOB, and Rupiah economics
5. **300 trade documents searchable** — Cortex Search on contracts, LCs, and market reports for trading intelligence


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRADING.RAW.TRADES` → 15000
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRADING.RAW.MARKET_PRICES` → 200000
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRADING.RAW.LOGISTICS` → 10000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRADING.ML.CPO_PRICE_FORECAST_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRADING.AI.DOC_EXTRACT_RESULTS` → 300
- [ ] `SELECT COUNT(*) FROM PALM_OIL_TRADING.AI.MARKET_COMMENTARY` → >0

