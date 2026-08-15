-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for CPO Trading Analytics
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.TRADE_DOCS_SEARCH
  ON CONTENT
  ATTRIBUTES DOC_TYPE, COUNTERPARTY, COMMODITY
  WAREHOUSE = TRADING_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.TRADE_DOCS
);
