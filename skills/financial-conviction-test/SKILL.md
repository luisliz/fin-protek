---
name: financial-conviction-test
description: Sort every holding into conviction vs drift vs froth to decide what to keep, trim, or sell.
---
# Financial - Conviction Test

Read `portfolio/holdings.md` and each `stocks/*/thesis.md`. For every holding, force the
question: would the user hold this UNTOUCHED through a 50% drawdown and mean it?

- **Conviction**: clear multi-year thesis they'd defend out loud.
- **Drift**: only big because it ran, or no current thesis.
- **Froth**: the user flags it a bubble themselves.

Rules:
- Drift and Froth are SELL candidates. Ask once whether tax on realized gains is a blocker and
  record the answer in `portfolio/holdings.md`. If it is not, proceeds → cash/T-bills is valid
  (raising cash is diversification).
- Conviction + oversized → trim-to-limit, not exit.
- Sizing fixes the disease; hand "protect this conviction hold" to
  `/fin-protek:financial-hedge-design`.

Output three labelled buckets + a one-line action per holding. Log each resulting decision via
`bin/ledger append --type decision ...` (never hand-edit the log).
