---
name: financial-exposure-map
description: Measures the portfolio. Which holdings are the same bet, does each goal's money fit its tolerance, is the income enough, and what limits to propose. Use for "am I overexposed", "am I diversified", "these two offset each other", "my sector cannot fall", "is my dividend income safe or enough", "is my house or college money at risk", "what should my limits be", concentration, correlation, or employer-stock questions. The only skill that runs goal tests and proposes limits; it decides no trade. Not for one company's fundamentals (financial-analyze-stock) or for what to sell (financial-conviction-test).
---
# Financial - Exposure Map

One question: which holdings are the same bet, and does each goal's money fit its tolerance? It
MEASURES and proposes, decides no trade, and other skills read its file. `$TMP` = session scratchpad.

## 1. Read first
- `portfolio/holdings.md`. Missing, or no Goals, "Outside this account" or Questions owed section
  → run `/fin-protek:financial-onboard`. Prices older than a month → flag stale, confirm positions.
  Money with no goal → ask which goal owns it; unanswered → "not run: assignment owed".
- `portfolio/playbook.md`; theses, fund notes and filings for step 4. Every figure cites its file
  and line, or the program output it came from.

## 2. Run the programs first (the board and step 6 read only this output)
- History, longest available, for every holding and the main income's employer ticker:
  `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<TICKER>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<TICKER>.json"`.
  No history → that holding is "not tested", kept out of `book` and of any "offsets" verdict.
- Per goal, only that goal's holdings and cash; cash set aside for another goal never enters:
  `bin/optcalc book --position <T>=<value>:"$TMP/px-<T>.json" ... --cash <this goal's cash> --tolerance <L> --corr-years 10`.
  `--tolerance` is a fraction (0.25 = 25%), passed for a confirmed or unconfirmed number and
  omitted otherwise. Tolerance 0 → omit it: anything but cash or short bills fails that goal.
- State the first common date and each crash it misses (2008, 2000-02, any the user names); a
  short-history holding that cuts one out → also run `book` without it.
- Income goal: `bin/optcalc income --holding <T>=<shares>:stocks/<T>/filings/companyfacts.json ... --other <NAME>=<AMOUNT> --need <N> --floor <F>`.
  Floor = need minus the bearable cut ("none" → floor = need; none confirmed → omit `--floor`).
  `--other`: a fund's distributions, user-supplied. No facts file → `/fin-protek:financial-fetch-filing <T>`;
  a row `facts` lacks → from the filing text (file, line), recomputed by a `python3 -I` script.
- Sum by a date: `bin/optcalc drawdown --history "$TMP/px-<T>.json" --ticker <T>` (days to recover).
- A belief the user stated ("tech and oil are opposites"): `bin/optcalc corr --history "$TMP/px-<A>.json" --ticker <A> --history "$TMP/px-<B>.json" --ticker <B>`.
  "They offset" only when one rose in the other's largest falls; no price rows → test the shared
  driver in the filings, labelled "not by price".

## 3. One test per goal (from step 2 output; one result line each)
- **Long-run pot**: worst replayed fall in dollars and %, with dates, against L. "Every position
  is inside its limit" never ends this test. **Sum by a date** ("standing" is within 5 years): the
  same against its tolerance; within 5 years, anything but cash or short bills is flagged with
  the dollar shortfall at the worst fall, and a recovery longer than the time left is named.
- **Income**, in this order, never by price fall: (a) ENOUGH: total yearly income against need and
  floor; a shortfall is a finding in dollars per year even when every dividend is covered. (b)
  COVERED: free cash flow against dividends paid, 3 years per holding (bank or insurer: net income
  to common). Before naming the weak payer, read the cash-flow statement and notes for one-offs in
  the low years; show cover with and without them; cover is a weak predictor of a cut. (c)
  CONCENTRATED: each holding's share of the income, and the largest two together.
- **Debt payoff**: the terms; the rate beside a T-bill yield the user supplies; the pot's `book`
  rerun with the holding to be sold moved to cash. The choice to pay down is the user's.
- Unconfirmed → "at your unconfirmed <X>"; not asked yet or declined → the worst fall in dollars.

## 4. Name the bets (a judgement from evidence)
- Per holding: sector, end market, largest customers, chokepoints, macro drivers; a fund, what it
  tracks and its overlap by a `python3 -I` script over its holdings file (none on disk →
  `/fin-protek:financial-fetch-filing <FUND>`; still none → "awaiting documents", price only).
- `book`'s pair evidence table SUGGESTS links; the map DECIDES. Each cluster gets one evidence
  line: correlation over the whole history and the last 10 years, each member's move in the
  other's largest falls, and the shared driver from the filings (same customers, cycle or
  regulator). Two holdings in one industry that fell together in the largest market fall they
  share are one bet unless the evidence shows otherwise. Departing from the program → say why.
- By a `python3 -I` script: each cluster's weight in its goal and share of the worst fall. Count
  independent drivers (clusters, unclustered holdings, cash); name each missing driver class.

## 5. Outside this account and the income-linked bet
- Each row: value or income, its shared driver and the holdings that share it (a debt: rate, reset date).
- Income-linked bet = holdings that share the main income's driver: the employer's stock and
  holdings in the same industry or cycle (step 4 evidence; self-employed: the industry of the
  work). Cap = L_main x this account's value (outside items never join it); run `book` on those
  holdings with `--tolerance` = cap / their value, by script, command shown. Unvested stock and
  plan purchases are listed beside it with dates as money that will arrive, never as held.
- L_main not asked yet → first line of Questions owed; "unlimited by the user's choice" only when declined.

## 6. Proposed limits (one rule for how much to cut)
- A goal's replay over a CONFIRMED tolerance → the pro-rata figure `book` prints for that goal is
  the only "what fits"; conviction-test picks who carries the cut. Per-holding and cluster values
  are information, never a trade. Unconfirmed → shown, "pending your confirmation of <X>".
- Income-linked bet: its pro-rata figure from step 5. Income goal: most one payer may supply =
  total income minus floor. Minimum cash = cash set aside + the unfunded part of each sum due
  within 5 years + what the user states. Minimum independent drivers: 2. Each by script.
- Ask the user to accept each; write it to Concentration limits in `holdings.md` as "accepted by
  the user on <date>" or "proposed on <date>". Proposed never places or schedules a sale.

## 7. Board
`/fin-protek:financial-red-team-board portfolio` with the step 2 output and step 4 cluster lines
(the macro seat checks the clusters). Answer each seat's strongest point, or change the map.

## 8. Output
Write `portfolio/exposure-map.md` with these sections, in order, every one present ("none" if empty):
`# Exposure map <YYYY-MM-DD>` (holdings priced on <date>); `## Questions owed`; `## Programs run`
(commands, first common date, crashes missed); `## Income-linked bet`; `## Outside this account`
(each row, its shared driver); `## Goal tests` (a `### <goal>` per goal: kind, tolerance and
state, result, shortfall or pro-rata figure); `## Clusters` (members, % of goal, share of worst
fall, evidence line); `## Beliefs tested`; `## Proposed limits` (value, state); `## Missing
drivers`; `## Board`; `## Verdict`. Tell the user in that order. "No breach" only when every goal
test ran against a confirmed tolerance and passed, L_main is answered and no unintended bet exists.
No ledger entry, no card: the skill that decides a trade does both.

## Next
- Breach, shortfall, unintended bet, or income-linked bet over its limit → `/fin-protek:financial-conviction-test`.
- No breach and a missing driver named → `/fin-protek:financial-find-ideas` with that line.
