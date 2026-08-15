-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for CPO Trading Analytics
-- ============================================================================
USE DATABASE PALM_OIL_TRADING;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.TRADING_INTELLIGENCE_AGENT
  COMMENT = 'CPO Trading Analytics AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'PALM_OIL_TRADING.APP.TRADING_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'PALM_OIL_TRADING.SEARCH.TRADE_DOCS_SEARCH', TOOL_DESCRIPTION => 'Search documents for Palm Oil & Agriculture information')
  )
  SYSTEM_PROMPT = 'You are the CPO Trading Intelligence Agent for an Indonesian palm oil trading house managing 15,000 trades with US$2.8B annual turnover across physical and derivative markets.';
