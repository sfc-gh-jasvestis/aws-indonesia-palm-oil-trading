-- ============================================================================
-- 08_native_settlements.sql - Snowflake-only build: live settlement feed without AWS.
-- Creates RAW.LIVE_SETTLEMENTS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_SETTLEMENTS(N), which inserts synthetic
-- buyer settlement events with the same value ranges and ~10% LATE rate as
-- aws/publish_settlements.py. Rows are inserted directly; this simulates a
-- trade settlement feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_SETTLEMENTS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_SETTLEMENTS (
  COUNTERPARTY_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, AMOUNT_USD FLOAT, DAYS_OVERDUE NUMBER,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_SETTLEMENTS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_SETTLEMENTS (COUNTERPARTY_ID, EVENT_TS, AMOUNT_USD, DAYS_OVERDUE, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'BUY-' || LPAD(UNIFORM(0, 119, RANDOM())::VARCHAR, 4, '0') AS COUNTERPARTY_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_LATE,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the amount is scaled outside it.
    SELECT COUNTERPARTY_ID, TS,
           ROUND(600000 * EXP(NORMAL(0, 0.6, RANDOM())), -2),
           IFF(IS_LATE, UNIFORM(1, 45, RANDOM()), 0),
           IFF(IS_LATE, 'LATE', 'SETTLED'), TS, 'APP.SIMULATE_SETTLEMENTS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_SETTLEMENTS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_SETTLEMENTS(5);
