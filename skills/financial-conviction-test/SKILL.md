---
name: financial-conviction-test
description: Decide which holdings to keep, trim, or sell, how far to cut a group of holdings that fall together (employer or industry stock included), and which holding to sell to fund a goal, from the measurements in the exposure map. Use when the user asks "what should I keep, trim or sell", "is this position too big", "should I sell my company stock", "should I keep buying through the stock plan", "should I sell something to pay down the mortgage", or "should I hold through a crash". Not for measuring exposure or testing a goal (financial-exposure-map), protecting a holding (financial-hedge-design), adding to one (financial-analyze-stock), or judging past decisions (financial-review).
---
# Financial - Conviction Test

Decides keep, trim or sell; measures nothing: every figure comes from `portfolio/exposure-map.md`,
and the one program run here is `bin/optcalc book`, to show a CHOSEN cut fits. A sale has one of
three reasons: merit (needs a thesis or fund note), size (above an accepted limit), or a goal.

## 1. Read first
- `portfolio/holdings.md` (missing → `/fin-protek:financial-onboard`, stop; price date over 30 days
  → confirm shares and prices, marked user-supplied): Goals, Outside this account, Trading rules,
  Concentration limits, Notes (tax per holding, cash set aside).
- `portfolio/exposure-map.md`. Missing, or dated before the holdings price date, the newest `fill`
  in `bin/ledger strategies`, or the newest row of a `stocks/<T>/filings/INDEX.md` → run
  `/fin-protek:financial-exposure-map` first and stop. Read, whatever the headings: the result per
  goal (worst replayed fall in dollars, dates, tolerance); each limit, proposed or accepted; the
  pro-rata figure per breach; the clusters and their evidence; the income checks (enough, covered,
  concentrated); the income-linked bet and its arrivals; each fund's status; the questions owed.
  A part missing → name it and rerun the map; never compute it here.
- `portfolio/playbook.md` (missing → "no user rules on file") and each `stocks/<T>/thesis.md`.

## 2. The state of each answer
Each tolerance, L_main and limit is confirmed or accepted; unconfirmed ("40%, not sure"); proposed;
not asked yet; or declined (asked and refused). Ask the map's questions owed first, in one batch.
- Only a CONFIRMED tolerance or an ACCEPTED limit schedules a sale. Otherwise show the map's figure
  with the fall in dollars, ask, and stop that part at "pending your confirmation of <X>".
- Confirmed as shown → recorded with the date by `/fin-protek:financial-onboard`. Changed → record
  it and rerun the map. Declined → the map's worst fall in dollars beside the verdict, never "no breach".

## 3. Merit buckets
- **Dollar question** (long-run pot or dated sum), per cluster and unclustered holding: "This bet is
  $V. In its worst replayed fall (<dates>, map) it lost $X. Would you hold it untouched through that,
  and mean it?" A single stock: at least a 50% fall. One portfolio answer covers all; none → "unanswered".
- **Income goal holdings** never get the price question: merit rests on the thesis and the map's
  COVERED result without disclosed one-offs (cover is a weak predictor of a cut).
- **Conviction**: a thesis the user has read and defends, and "yes" (income: cover passes).
  **Drift**: a thesis and "no", or weight that came only from a price run. **Froth**: the user
  calls it a bubble. **Unanswered**: no merit sale.
- **Not assessed**: a company with no thesis; never a sell candidate for that reason (size and goal
  sales still apply) → `/fin-protek:financial-analyze-stock <T>`.
- **Funds**: a fund note makes it assessed. A fund the map marks "awaiting documents" is said to be
  so: no merit verdict, size and goal apply; ask for its prospectus and holdings list.
A drift name that is the book's only independent driver (map) is a trim, not a sale.

## 4. How much to cut: one rule
For each breach of a confirmed tolerance or accepted limit (a goal, a cluster, the income-linked bet):
1. Start from the map's pro-rata figure: that goal's holdings scaled together until the replay fits.
   It is the only figure called "what fits"; per-holding limit rows are information, never the trade.
2. Choose which holdings carry the cut, with the reason: merit (drift, froth), tax (Notes), trading
   rules (closed window, ban), or the map's largest contributor. "Sell all of X" is never the
   program's verdict; a full sale of one holding is the user's choice, said so.
3. Re-run `book` on the chosen cut, that goal's holdings and cash only (`$TMP` = session scratchpad):
   `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<T>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<T>.json"`, then
   `bin/optcalc book --position <T>=<value after>:"$TMP/px-<T>.json" ... --cash <goal cash> --tolerance <L>`.
   It does not fit → change the choice or take pro rata. Tolerance 0 → cash or short bills only; no run.

## 5. Actions
- **Size**: above an accepted limit → the step 4 cut, reason "size"; no thesis needed.
- **Goal** (sum by a date, debt payoff): the money to raise, carried as in step 4; proceeds to cash
  or T-bills, set aside. Paying down debt is the user's choice; show the long-run pot re-run after.
- **Income**: ENOUGH fails → the map's gap in dollars a year and the user's options: a cash reserve,
  drawing on principal, a lower need, or other holdings via `/fin-protek:financial-find-ideas`.
  Weigh every sale by the income it removes a year (map) and as a share of the need.
- **Income-linked bet** (holdings sharing the main income's driver, per the map) above its accepted
  limit → cut by step 4; each arrival (vest, plan purchase, deferred pay; not held until it arrives)
  defaults to a sale at the first date the window, pre-clearance and minimum holding period allow.
  L_main not asked → a question owed, no sale.
- **Purchase plan**, discount d: gain at least d / (1 - d) on money put in, more with a lookback;
  the risk is the price move from each purchase to its first allowed sale. Tax: the plan documents.
- Conviction inside every accepted limit → keep. Drift or froth → sell candidate. Cash or "keep all"
  is valid. Every trim or sale is a **staged plan**: dated stages inside open windows, after
  pre-clearance, or the employer's pre-arranged selling plan, each checked against every ban's scope.
- **Tax blocks a sale** (Notes; ask only if blank): a trim staged across tax years, or a hedge when
  the holding has conviction or must shrink, contracts × 100 ≤ shares held, and options are not
  barred. Neither → "unprotected by the user's choice". Never drop it; never touch cash set aside.
- **Behaviours**: name the habit seen (anchoring on cost basis, selling after drops, buying what
  ran, a familiar employer) and propose a rule set in advance ("no sale within N days of an X% fall
  unless an early-disproof fact is met"; N, X the user's) as `--behaviour_proposal` for review.

## 6. Board, then present
Run `/fin-protek:financial-red-team-board portfolio <buckets and actions>` with the map and each
`book` re-run as text; it picks the seats and judges the decisions, not the measurements. Answer its
strongest point specifically BEFORE presenting. Table: holding or bet | value | map result | answer
state | bucket | action | stages. Write bucket, dated answer and Position into each `thesis.md`.

## 7. Log every decision, then the card
Strategy ids are lowercase: `<ticker>-core`; goal-level `portfolio-<goal>`. No strategy → `--type
open` adopts it; existing → `--type adjust`. Status pending until the user confirms a fill:
`bin/ledger append --type open --strategy <ticker>-core --ticker <T> --status pending --action "keep | trim N in stages <dates> | sell N for <goal> | not assessed | pending your confirmation of <X>" --origin "AI-suggested" --reason "merit | size | goal" --bucket "..." --answer "words, date, state" --book "map fall; re-run after" --plan "stages, arrivals" --tax "..." --behaviour_proposal "..." --counter_case "board's point" --evidence "exposure-map.md <date>; file:line" --horizon_years "N" --early_disproof "BUSINESS facts" --expectation "..." --confidence "low|med|high"`
Size, goal or not assessed: `--horizon_years "n/a" --early_disproof "size|goal rule | not assessed"`.
`fill` only on the user's confirmed execution, with price; `close` only after that fill, with `--proceeds_to`.
Last step, the card: a sale in one ticker → `/fin-protek:financial-sheet <TICKER> trade`; one reason
across several tickers → `/fin-protek:financial-sheet portfolio trade`; else `/fin-protek:financial-sheet portfolio`.

## Next
- Not assessed → `/fin-protek:financial-analyze-stock <T>`, then rerun this test.
- Conviction kept, or must shrink AND tax blocks the sale → `/fin-protek:financial-hedge-design <T>`; cash freed and not set aside → `/fin-protek:financial-find-ideas`.
