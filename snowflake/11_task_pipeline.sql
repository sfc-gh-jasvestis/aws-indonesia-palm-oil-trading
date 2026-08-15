-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for CPO Trading Analytics
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_INGEST_PRICES
  WAREHOUSE = TRADING_WH
  SCHEDULE = 'USING CRON 0 */1 * * * UTC'
  COMMENT = 'Ingest latest BMD futures and physical pricing'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_REFRESH_POSITIONS
  WAREHOUSE = TRADING_WH
  AFTER APP.TASK_INGEST_PRICES
  COMMENT = 'Refresh position book and mark-to-market'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_FORECAST_PRICES
  WAREHOUSE = TRADING_WH
  AFTER APP.TASK_REFRESH_POSITIONS
  COMMENT = 'Run ML.FORECAST on CPO forward curve'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_FORECAST_PRICES RESUME;
ALTER TASK APP.TASK_REFRESH_POSITIONS RESUME;
ALTER TASK APP.TASK_INGEST_PRICES RESUME;
