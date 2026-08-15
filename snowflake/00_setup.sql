-- ============================================================================
-- CPO Trading Analytics
-- Real-time CPO trading intelligence for Indonesia's US$28B palm oil export market — ML.FORECAST projects price movements, Dynamic Tables build position books, and Cortex AI generates market commentary.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS PALM_OIL_TRADING;
CREATE WAREHOUSE IF NOT EXISTS TRADING_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE PALM_OIL_TRADING;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE TRADING_WH;
