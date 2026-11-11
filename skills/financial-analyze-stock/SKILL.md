---
name: financial-analyze-stock
description: Deep fundamental analysis of one holding or candidate from its actual filings. Use when the user asks to analyze, value, vet, or get an opinion on a specific ticker.
---
# Financial - Analyze Stock: $ARGUMENTS

Evaluate the MARGINAL position, grounded in real documents. Works COLD: assume no memory.

0. Re-orient. List `stocks/$ARGUMENTS/filings/` and `stocks/$ARGUMENTS/reading/` with each
   document's type + date. Read `portfolio/holdings.md` (flag if stale) and
   `stocks/$ARGUMENTS/thesis.md` if present. NO filings → STOP and ask for them, or run
   `/fin-protek:financial-fetch-filing $ARGUMENTS`; do not opine on a name whose documents you
   haven't read.
1. Identify the document type and navigate by ITS structure:
   - 10-K (annual): Item 1/1A business+risk, Item 3 legal, Item 7 MD&A, Item 7A market risk,
     Item 8 statements + FOOTNOTES.
   - 10-Q (quarterly): fresher MD&A, q/q trends, updated risk factors, liquidity.
   - Prospectus / S-1 / 424B (IPO): business, risk factors, USE OF PROCEEDS, MD&A,
     financials, DILUTION, LOCK-UP expirations, selling-shareholder intent.
   - 8-K: the specific material event and its terms.
2. Mandatory extraction, BEFORE any opinion; do not substitute ESG/business-description fluff:
   revenue + margins (3 yr / full history if IPO); operating cash flow vs net income; debt,
   maturities, covenants, coverage; share count + dilution (IPO: lock-up size & expiry);
   segment breakdown; DATED/QUANTIFIED constraints; YoY risk-factor wording changes.
   Hardware/semi → trace supply chain (fab, packaging, sole-source, customer concentration)
   and which other holdings share that chokepoint.
3. Need a current price/multiple? ASK. There is no live feed; never invent one.
4. Form the bull thesis + variant perception.
5. INDEPENDENT ADVERSARY: dispatch the `fin-protek:financial-red-team` subagent with the ticker
   and your extracted numbers. Engage its strongest points SPECIFICALLY: rebut each concretely
   or concede the thesis is weaker than you thought.
6. Risk/reward (size the downside first) → discipline (entry/exit/what changes my mind).
7. Record. Update `stocks/$ARGUMENTS/thesis.md`. If you recommend an action, log it via the
   PROGRAM, never by hand-editing the log:
   `bin/ledger append --type decision --ticker $ARGUMENTS --action "..." --origin "AI-suggested"
    --reasoning "..." --evidence "src+location for every number" --counter_case "..."
    --horizon_years "N" --early_disproof "BUSINESS facts that break the thesis, not a price move"
    --expectation "..." --confidence "low|med|high"`
   END with the MARGINAL verdict: independent return driver, or doubling a bet already in the book?

Cite every number to source + location. Close with the not-advice caveat.
