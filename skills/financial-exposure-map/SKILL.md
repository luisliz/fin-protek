---
name: financial-exposure-map
description: Look-through correlation and overexposure analysis across the whole portfolio. Use for "am I overexposed", diversification, concentration, or correlation questions.
---
# Financial - Exposure Map

Read `portfolio/holdings.md` (and `stocks/*/thesis.md` for context). Tickers are NOT
diversification (Dalio: count uncorrelated return streams). Map every holding + any candidate:
sector; END-MARKET / demand driver (NVDA & AMD both "AI-datacenter GPU demand"); geographic
revenue; supply-chain chokepoints (shared TSMC = one point of failure); style factor; top 2-3
macro sensitivities.

Then:
1. Cluster holdings sharing >= 2 dimensions. Each cluster is ONE bet. Report weight per cluster.
2. Check against the user's limits; flag breaches WITH THE MATH
   ("NVDA 18% + AMD 12% = 30% AI-GPU vs 25% cap → +5pts over").
3. Count independent return drivers vs the user's minimum.
4. Tail check: the SINGLE macro shock hitting the most clusters at once (correlations → 1 in a
   selloff; weight shared TAIL risk).
5. INDIRECT exposure: look through any index/ETF holding to its top constituents and fold them in.

Output a ranked concentration table + the single biggest UNINTENDED bet. If the user acts, log via
`bin/ledger append --type decision ...`.
