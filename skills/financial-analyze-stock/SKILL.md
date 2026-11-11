---
name: financial-analyze-stock
description: Writes or tests the thesis for one company from its actual filings, and runs the ADD gate before any share or fund purchase. Use when the user asks to analyze, value, vet, or get an opinion on a ticker, asks "should I buy more of X" or "is this dividend safe", or a holding has no written thesis ("not assessed"). Not for portfolio-wide questions (financial-exposure-map), keep/trim/sell across the book (financial-conviction-test), or a name with no filings on disk (financial-fetch-filing first).
---
# Financial - Analyze Stock: $ARGUMENTS

TICKER = the first word of `$ARGUMENTS`; the rest says what is asked (e.g. `add for income`).
Use `<TICKER>` in paths and `<ticker>` (lowercase) in strategy ids. Evaluate the MARGINAL
position from real documents. Works COLD: assume no memory. `$TMP` = the session scratchpad.

## 0. Re-orient
- `portfolio/holdings.md`. Missing → run `/fin-protek:financial-onboard` first. Stale date →
  confirm share counts. Note the **Goals** row this money serves; **Outside this account** items
  sharing a driver with TICKER; **Trading rules** (each ban's action and scope); Notes (tax, set-aside).
- `portfolio/exposure-map.md`: goal test results, limits and their state (accepted or proposed),
  clusters, the income-linked bet, Questions owed. Missing or older than `holdings.md` → the
  thesis may proceed; the ADD gate waits for `/fin-protek:financial-exposure-map`.
- `portfolio/playbook.md`: Limits, Sizing rules, Exit rules. Missing → say so.
- `stocks/<TICKER>/filings/`. NO filings → STOP; run `/fin-protek:financial-fetch-filing
  <TICKER>`; no opinion before that. Filings and no `INDEX.md` → build it by fetch-filing's
  backfill step (no network needed). Only "statements" rows count as the latest annual: the
  newest is "no statements" or "cover page" → fetch-filing for the original or the exhibit; not
  fetchable → say the current annual is missing and use the last one with statements. Prior
  annual missing and not fetchable → risk changes NOT FOUND.
- **A fund** gets no thesis: its fund note is its assessment ("awaiting documents" counts as
  noted). Note missing → fetch-filing's Funds section; skip steps 1-2 and 4.
- `stocks/<TICKER>/thesis.md`. Missing, template text, or older than the newest "statements"
  filing → **not assessed**: no keep or add verdict until steps 1-6 have run.

## 1. Navigate by the document's structure
Annual: risk factors, legal, MD&A, market risk, statements and FOOTNOTES. 10-Q / 6-K: fresher
MD&A and liquidity. S-1 / 424B: use of proceeds, DILUTION, LOCK-UPs. 8-K: the event and its terms.

## 2. Extract BEFORE any opinion (no business-description fluff)
- `extracted-financials.md` whose header accessions match the manifest's newest rows → reuse it.
  Otherwise start from `bin/optcalc facts --facts stocks/<TICKER>/filings/companyfacts.json --ticker <TICKER>`
  and add only the new filing, in fetch-filing's format. No facts file → run fetch-filing. A
  needed figure prints NOT FOUND → read it from the filing text, cite file:line, say the tag was missing.
- From the text: debt maturities, covenants, coverage; dilution; segments; DATED, quantified
  constraints; risk wording added or removed since the prior annual. Hardware or semis → fab,
  packaging, sole-source, customer concentration, and which holdings share them.
- **Dividends**: per share, paid, and cover for 3 years by fetch-filing's rule (bank variant
  included). Before calling cover weak, read the cash-flow notes for one-offs in the low years;
  show cover with and without them, cited, and say cover is a weak predictor of a cut. Ratios by a
  `python3 -I` script, never by the model.

## 3. Prices
No live feed: ask for today's price, marked user-supplied. History (main thread) for TICKER and
each holding of the money's goal: `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<T>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<T>.json"`,
then `bin/optcalc drawdown --history "$TMP/px-<TICKER>.json" --ticker <TICKER>`. State the first
date and any crash the user names that it misses. Fetch fails → "worst fall unknown"; gate 2 fails.

## 4. Thesis (always written, even when the add is refused)
Write the falsifiable thesis and variant perception (who is on the other side, and why) to
`stocks/<TICKER>/thesis.md`; for an income goal's payer, the dividend counted on and the cover
that keeps it. Bucket: "not assessed by the user"; only conviction-test sets conviction or drift.

## 5. Independent adversary (every thesis, add or not)
Run `/fin-protek:financial-red-team-board <TICKER> <decision>` before the thesis is final; the
decision names any add refused in step 7. The board picks the seats and does not log; when it
runs a forensic seat, that seat recomputes from the filing. Engage each seat's strongest point
SPECIFICALLY: rebut with a citation, or concede and weaken the thesis.

## 6. Risk/reward and discipline (downside first)
Income goal → income lost if this dividend halves, in dollars and as a share of the goal's income,
from `bin/optcalc income` output. Then entry, exit, and the business facts that change your mind;
a tax-blocked TICKER (Notes) → a sale realizes a taxed gain; offer a trim staged across tax years.

## 7. ADD gate (shares or fund; all must pass, any fail → no add)
1. A written thesis or fund note, current after step 0.
2. **Goal fit, read from the map**: the goal's tolerance is confirmed, and the limits on
   TICKER, its cluster and the income-linked bet are ACCEPTED with room. A proposed limit, an
   unconfirmed tolerance or a Questions owed item for this goal → no add; name the confirmation
   owed. Declined → no add; show the map's worst replayed fall. Then show the goal fits after the
   buy, the one test this skill runs: pot or dated goal → `bin/optcalc book` on that goal's
   holdings plus the add and its cash minus the cost, `--tolerance <its L>`; income goal →
   `bin/optcalc income` with the add: the gap to the need shrinks or closes and no payer passes
   its accepted share (no price tolerance needed). A sum due within 5 years takes no shares; a
   cash equivalent or short bill needs no tolerance.
3. Trading rules: an open window; TICKER outside every purchase ban's scope; the income-linked
   bet over its accepted limit → no add, each vest or plan purchase defaults to a sale. Money
   assigned to another goal or set aside is never used.
4. The board in step 5 left no unanswered fatal objection.

## 8. Record
Update `stocks/<TICKER>/thesis.md` (Position, strongest bear case). Log through the PROGRAM only,
once per decision; a held name with no strategy gets `--type open` here first:
`bin/ledger append --type open|adjust --strategy <ticker>-core --ticker <TICKER> --action "..."
 --origin "AI-suggested" --reasoning "..." --evidence "file:line for every number; board seats run"
 --counter_case "..." --horizon_years "N" --early_disproof "BUSINESS facts, not a price move"
 --expectation "..." --confidence "low|med|high" --asof YYYY-MM-DD --status pending`
On the user's confirmed fill: `--type fill --strategy <ticker>-core --ref <seq>`, price and
quantity. END with the MARGINAL verdict: independent driver, or one more ticker on a bet held.
"No action" is valid; log a no-add too, naming the failed gate and any confirmation owed. Tell the
user the verdict, gate results, worst replayed fall, and what was logged. Not advice.

## Next
- Strategy logged → build the card now: `/fin-protek:financial-sheet <TICKER> thesis`.
- Then: an add filled → `/fin-protek:financial-exposure-map`; a confirmation owed → ask it, rerun.
