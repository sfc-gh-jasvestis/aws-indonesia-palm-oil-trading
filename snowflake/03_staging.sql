-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.SETTLEMENT_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.SETTLEMENT_DAILY observation
    LEFT JOIN RAW.COUNTERPARTIES counterparty ON counterparty.ID = observation.ENTITY_ID
    WHERE counterparty.ID IS NULL OR observation.DAYS_OVERDUE < 0
       OR observation.OPEN_EXPOSURE_USD < 0 OR observation.LC_HEADROOM_USD < 0
       OR observation.SETTLEMENT_LATE > observation.SETTLEMENT_DUE
       OR observation.INVOICE_SETTLED_USD > observation.INVOICE_DUE_USD
       OR observation.PAYMENT_COMMITMENT > observation.CREDIT_FOLLOWUP
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
