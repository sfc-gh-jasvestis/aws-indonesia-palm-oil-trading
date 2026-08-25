-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for CPO Trading Analytics
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_indonesia_palm_oil_trading_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: POSITION_LIMIT_ALERT
CREATE OR REPLACE ALERT APP.POSITION_LIMIT_ALERT
  WAREHOUSE = TRADING_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Counterparty position limit breach'
IF (EXISTS (
  SELECT 1 FROM CURATED.POSITION_BOOK
  WHERE 1=1 -- Condition: Net position exceeds approved limit for any counterparty
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_palm_oil_trading_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] CPO Trading Analytics: Counterparty position limit breach',
    'Counterparty position limit breach'
  );

ALTER ALERT APP.POSITION_LIMIT_ALERT RESUME;

-- Alert: VESSEL_DELAY_ALERT
CREATE OR REPLACE ALERT APP.VESSEL_DELAY_ALERT
  WAREHOUSE = TRADING_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Vessel delay exceeds 5-day threshold — demurrage risk'
IF (EXISTS (
  SELECT 1 FROM CURATED.POSITION_BOOK
  WHERE 1=1 -- Condition: Vessel ETA deviation > 5 days
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_indonesia_palm_oil_trading_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] CPO Trading Analytics: Vessel delay exceeds 5-day threshold — demurrage risk',
    'Vessel delay exceeds 5-day threshold — demurrage risk'
  );

ALTER ALERT APP.VESSEL_DELAY_ALERT RESUME;

