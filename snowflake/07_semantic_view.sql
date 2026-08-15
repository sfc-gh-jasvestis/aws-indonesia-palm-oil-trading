-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for CPO Trading Analytics
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.TRADING_ANALYTICS
  COMMENT = 'CPO trading positions, pricing, risk, and logistics analytics'
AS
  TABLES (
    CURATED.POSITION_BOOK AS position_book,CURATED.FORWARD_CURVE AS forward_curve,CURATED.LOGISTICS_STATUS AS logistics_status,CURATED.LEVY_IMPACT AS levy_impact
  );
