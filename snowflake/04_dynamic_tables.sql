-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for CPO Trading Analytics
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA CURATED;

-- POSITION_BOOK: Real-time net position by commodity, month, and counterparty with MTM
-- Source: TRADES, POSITIONS, MARKET_PRICES
CREATE OR REPLACE DYNAMIC TABLE CURATED.POSITION_BOOK
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRADING_WH
AS
SELECT * FROM RAW.TRADES;
-- TODO: Replace with actual join/aggregation logic per demo

-- FORWARD_CURVE: CPO forward curve construction from futures and physical premiums
-- Source: MARKET_PRICES
CREATE OR REPLACE DYNAMIC TABLE CURATED.FORWARD_CURVE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRADING_WH
AS
SELECT * FROM RAW.MARKET_PRICES;
-- TODO: Replace with actual join/aggregation logic per demo

-- LOGISTICS_STATUS: Vessel tracking with ETA, delay flags, and cost impact
-- Source: LOGISTICS, TRADES
CREATE OR REPLACE DYNAMIC TABLE CURATED.LOGISTICS_STATUS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRADING_WH
AS
SELECT * FROM RAW.LOGISTICS;
-- TODO: Replace with actual join/aggregation logic per demo

-- LEVY_IMPACT: Export levy calculation and margin impact per shipment
-- Source: EXPORT_LEVY, TRADES, MARKET_PRICES
CREATE OR REPLACE DYNAMIC TABLE CURATED.LEVY_IMPACT
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRADING_WH
AS
SELECT * FROM RAW.EXPORT_LEVY;
-- TODO: Replace with actual join/aggregation logic per demo

