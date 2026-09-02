-- Generated from generator/demo_specs/aws-indonesia-palm-oil-trading.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-indonesia-palm-oil-trading
-- This is the schema that is actually deployed for ID_PALM_OIL_TRADING.

-- ID_PALM_OIL_TRADING  (CPO Trading Analytics)
-- generated from generator/demo_specs/aws-indonesia-palm-oil-trading.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS ID_PALM_OIL_TRADING;
CREATE SCHEMA IF NOT EXISTS ID_PALM_OIL_TRADING.RAW;
CREATE SCHEMA IF NOT EXISTS ID_PALM_OIL_TRADING.CURATED;
CREATE SCHEMA IF NOT EXISTS ID_PALM_OIL_TRADING.APP;
USE DATABASE ID_PALM_OIL_TRADING;

-- 5 real regions; entity names carry their region so the two always agree
