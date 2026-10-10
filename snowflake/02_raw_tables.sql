-- Synthetic counterparty-day observations for a fictional Indonesian palm oil trading desk.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-counterparty cash-flow stress cycles that show up first in
-- letter-of-credit headroom and then in late settlements, a small distressed cohort,
-- weekly or fortnightly settlement schedules, a loading-delay shock, and
-- credit-desk follow-ups. Buyers, prices and amounts are fictional.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.COUNTERPARTIES AS
WITH counterparties AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS COUNTERPARTY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 120))
), draws AS (
  SELECT COUNTERPARTY_INDEX,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-score')), 1000000) / 1e6 AS U_SCORE,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-book')), 1000000) / 1e6 AS U_BOOK,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-size')), 1000000) / 1e6 AS U_SIZE,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-interval')), 1000000) / 1e6 AS U_INTERVAL,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-phase')), 1000000) / 1e6 AS U_PHASE,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-period')), 1000000) / 1e6 AS U_PERIOD,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-headroom')), 1000000) / 1e6 AS U_HEADROOM,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-distress')), 1000000) / 1e6 AS U_DISTRESS,
         MOD(ABS(HASH(COUNTERPARTY_INDEX, 'idpalm-onset')), 1000000) / 1e6 AS U_ONSET
  FROM counterparties
)
SELECT 'BUY-' || LPAD(COUNTERPARTY_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic buyer ' || LPAD(COUNTERPARTY_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread: every port city and product appears.
       CASE MOD(COUNTERPARTY_INDEX, 5) WHEN 0 THEN 'Dumai' WHEN 1 THEN 'Medan'
            WHEN 2 THEN 'Palembang' WHEN 3 THEN 'Pontianak' ELSE 'Balikpapan' END AS REGION,
       CASE MOD(COUNTERPARTY_INDEX, 8) WHEN 0 THEN 'Crude Palm Oil' WHEN 1 THEN 'Crude Palm Oil' WHEN 2 THEN 'Crude Palm Oil'
            WHEN 3 THEN 'RBD Palm Olein' WHEN 4 THEN 'RBD Palm Olein' WHEN 5 THEN 'RBD Palm Stearin'
            WHEN 6 THEN 'Palm Kernel Oil' ELSE 'Palm Fatty Acid Distillate' END AS CATEGORY,
       COUNTERPARTY_INDEX,
       -- Synthetic internal counterparty credit score (0-100); not an external rating.
       ROUND(35 + U_SCORE * 60, 0) AS CREDIT_SCORE,
       1 + FLOOR(U_BOOK * 24) AS MONTHS_TRADING,
       ROUND(CASE MOD(COUNTERPARTY_INDEX, 8) WHEN 0 THEN 8000000 WHEN 1 THEN 8000000 WHEN 2 THEN 8000000
                  WHEN 3 THEN 10000000 WHEN 4 THEN 10000000 WHEN 5 THEN 7000000
                  WHEN 6 THEN 12000000 ELSE 5000000 END * (0.6 + 0.8 * U_SIZE), -3) AS CONTRACT_VALUE_USD,
       7 * (1 + FLOOR(U_INTERVAL * 2)) AS SETTLEMENT_INTERVAL_DAYS,
       -- Base probability of a late settlement: weaker scores run late more; ~12% are chronic.
       (0.02 + (1 - U_SCORE) * 0.10) * IFF(U_RATE > 0.88, 2.5, 1) AS BASE_LATE_RATE,
       U_PHASE AS STRESS_PHASE,
       30 + FLOOR(U_PERIOD * 30) AS STRESS_PERIOD_DAYS,
       ROUND(CASE MOD(COUNTERPARTY_INDEX, 8) WHEN 0 THEN 1200000 WHEN 1 THEN 1200000 WHEN 2 THEN 1200000
                  WHEN 3 THEN 1500000 WHEN 4 THEN 1500000 WHEN 5 THEN 1000000
                  WHEN 6 THEN 1800000 ELSE 800000 END * (0.7 + 0.6 * U_HEADROOM), -3) AS BASE_LC_HEADROOM_USD,
       -- About 7% of buyers (more among weak scores) stop settling from a seeded onset day.
       IFF(U_DISTRESS < 0.03 + 0.08 * (1 - U_SCORE), 15 + FLOOR(U_ONSET * 65), NULL) AS DISTRESS_ONSET_DAY,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.SETTLEMENT_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), base AS (
  SELECT b.ID AS ENTITY_ID, b.COUNTERPARTY_INDEX, b.CATEGORY, b.REGION, b.CONTRACT_VALUE_USD,
         b.SETTLEMENT_INTERVAL_DAYS, b.BASE_LATE_RATE, b.BASE_LC_HEADROOM_USD,
         COALESCE(d.DAY_INDEX >= b.DISTRESS_ONSET_DAY, FALSE) AS DEFAULTED,
         COALESCE(d.DAY_INDEX >= b.DISTRESS_ONSET_DAY - 10, FALSE) AS PRE_DEFAULT,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + b.COUNTERPARTY_INDEX * 3, b.SETTLEMENT_INTERVAL_DAYS) = 0 AS IS_DUE,
         -- Buyer cash-flow stress cycle in [0, 1]; a 15-day loading-delay shock at Pontianak.
         LEAST(1, 0.5 + 0.5 * SIN(2 * PI() * (d.DAY_INDEX / b.STRESS_PERIOD_DAYS + b.STRESS_PHASE))
               + IFF(b.REGION = 'Pontianak' AND d.DAY_INDEX BETWEEN 48 AND 62, 0.35, 0)) AS STRESS,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'idpalm-pay')), 1000000) / 1e6 AS U_PAY,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'idpalm-headroom')), 1000000) / 1e6 AS U_HEADROOM,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'idpalm-sessions')), 1000000) / 1e6 AS U_SESSIONS,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'idpalm-contact')), 1000000) / 1e6 AS U_CONTACT,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'idpalm-ptp')), 1000000) / 1e6 AS U_PTP,
         MOD(ABS(HASH(b.ID, d.DAY_INDEX, 'idpalm-channel')), 1000000) / 1e6 AS U_CHANNEL
  FROM RAW.COUNTERPARTIES b CROSS JOIN days d
), dues AS (
  SELECT *,
         IFF(IS_DUE, 1, 0) AS SETTLEMENT_DUE,
         IFF(IS_DUE AND (DEFAULTED OR U_PAY < LEAST(0.9, BASE_LATE_RATE * (0.2 + 2.6 * STRESS))), 1, 0) AS SETTLEMENT_LATE
  FROM base
), streaks AS (
  -- Consecutive late settlements form one overdue streak; a settled invoice cures it.
  SELECT *,
         SUM(IFF(IS_DUE AND SETTLEMENT_LATE = 0, 1, 0))
           OVER (PARTITION BY ENTITY_ID ORDER BY DAY_INDEX ROWS UNBOUNDED PRECEDING) AS PAID_GROUP
  FROM dues
), streak_start AS (
  SELECT *,
         MIN(IFF(SETTLEMENT_LATE = 1, DAY_INDEX, NULL))
           OVER (PARTITION BY ENTITY_ID, PAID_GROUP) AS STREAK_START_DAY
  FROM streaks
), overdue_days AS (
  SELECT *,
         LAST_VALUE(IFF(IS_DUE, SETTLEMENT_LATE, NULL)) IGNORE NULLS
           OVER (PARTITION BY ENTITY_ID ORDER BY DAY_INDEX ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LAST_DUE_LATE,
         LAST_VALUE(IFF(IS_DUE, STREAK_START_DAY, NULL)) IGNORE NULLS
           OVER (PARTITION BY ENTITY_ID ORDER BY DAY_INDEX ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LAST_STREAK_START
  FROM streak_start
), measured AS (
  SELECT *,
         IFF(LAST_DUE_LATE = 1, DAY_INDEX - LAST_STREAK_START, 0) AS DAYS_OVERDUE,
         ROUND(CONTRACT_VALUE_USD * SETTLEMENT_INTERVAL_DAYS / 180 , -2) AS INVOICE_USD
  FROM overdue_days
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       SETTLEMENT_DUE, SETTLEMENT_LATE,
       SETTLEMENT_DUE * INVOICE_USD AS INVOICE_DUE_USD,
       (SETTLEMENT_DUE - SETTLEMENT_LATE) * INVOICE_USD AS INVOICE_SETTLED_USD,
       DAYS_OVERDUE,
       ROUND(CONTRACT_VALUE_USD * GREATEST(0.15, 1 - DAY_INDEX / 200), -3) AS OPEN_EXPOSURE_USD,
       -- Credit-desk follow-up on overdue days (1-60 days); a payment commitment on some follow-ups.
       IFF(DAYS_OVERDUE BETWEEN 1 AND 60 AND U_CONTACT < 0.35, 1, 0) AS CREDIT_FOLLOWUP,
       IFF(DAYS_OVERDUE BETWEEN 1 AND 60 AND U_CONTACT < 0.35 AND U_PTP < 0.75 - 0.5 * STRESS, 1, 0) AS PAYMENT_COMMITMENT,
       CASE WHEN NOT (DAYS_OVERDUE BETWEEN 1 AND 60 AND U_CONTACT < 0.35) THEN 'None'
            WHEN DAYS_OVERDUE <= 7 THEN IFF(U_CHANNEL < 0.6, 'Email', 'Trader call')
            WHEN DAYS_OVERDUE <= 30 THEN IFF(U_CHANNEL < 0.5, 'Trader call', 'Credit desk call')
            ELSE IFF(U_CHANNEL < 0.7, 'Credit desk call', 'LC claim review') END AS FOLLOWUP_CHANNEL,
       -- Leading indicator: LC headroom falls with buyer stress, and sharply ~10 days before distress.
       ROUND(BASE_LC_HEADROOM_USD * IFF(PRE_DEFAULT, 0.35, 1) * (1.3 - 0.9 * STRESS) * (0.75 + 0.5 * U_HEADROOM), -3) AS LC_HEADROOM_USD,
       ROUND(2 + 6 * (1 - STRESS) * U_SESSIONS + 2 * U_SESSIONS) AS VESSEL_NOMINATIONS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Shipping and trade-finance document coverage per buyer (snapshot).
CREATE TABLE RAW.SHIPPING_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Crude Palm Oil' THEN 'Certificate of analysis' WHEN 'RBD Palm Olein' THEN 'Bill of lading'
                     WHEN 'RBD Palm Stearin' THEN 'Surveyor weight report'
                     WHEN 'Palm Kernel Oil' THEN 'Letter of credit' ELSE 'Certificate of origin' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'idpalm-req')), 3) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'idpalm-file')), 4) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'idpalm-file')), 4) < 1 + MOD(ABS(HASH(ID, 'idpalm-req')), 3),
           MOD(ABS(HASH(ID, 'idpalm-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.COUNTERPARTIES;
