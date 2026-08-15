-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for CPO Trading Analytics
-- Country: INDONESIA | Currency: IDR
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- TRADES: 15,000 rows — Physical and derivative CPO/PKO trades with counterparty and pricing
-- POSITIONS: 5,000 rows — Net position by commodity, delivery month, and counterparty
-- MARKET_PRICES: 200,000 rows — BMD futures, Rotterdam CIF, FOB Belawan, and basis spreads
-- LOGISTICS: 10,000 rows — Vessel nominations, loading schedules, and shipment tracking
-- TRADE_DOCS: 300 rows — Contracts, letters of credit, shipping documents, and market reports
-- EXPORT_LEVY: 100 rows — Indonesian export levy and reference price history
