---
name: financial-position-check
description: Check what changed since the last check on open strategies, their orders, and each goal's result in the exposure map. Tests each logged early-disproof condition against new filings, re-prices option exit orders, lists what arrives from outside the account before the next check (vests, plan purchases, deferred pay, a loan reset), and records the check in the ledger. Use when a filing lands, a trigger price is hit, a sell-by or check date arrives, or the user asks "how is my hedge doing", "am I still on track" or "update my orders". Not for keep/trim/sell on shares (financial-conviction-test), measuring exposure (financial-exposure-map), adding to a name (financial-analyze-stock), or a new hedge or bet.
---
# Financial - Position Check: $ARGUMENTS

`$ARGUMENTS` is a TICKER or a strategy id (e.g. `xyz-hedge-2027-06-18`). Empty = every strategy
`bin/ledger strategies` lists, and every goal. `$TMP` is the session scratchpad; fetch on the main thread.

A strategy runs `open` → `fill` → `check` → `adjust` → `close` → `review`, one ledger entry each,
carrying `--strategy <id>`; entries are never edited. Strategy ids are lowercase. A hedge and its
shares are TWO strategies: a hedge sold to fund shares closes, and the purchase goes to
`/fin-protek:financial-analyze-stock`.

## 1. Re-orient cold
- No `decisions/ledger.log` → nothing is open; do steps 2 (arrivals only), 4 and 8, and say so.
  Otherwise `bin/ledger verify`; a broken chain → stop and report it.
- `portfolio/holdings.md` (missing → `/fin-protek:financial-onboard`; price date older than 30
  days → confirm share counts): Goals, Outside this account, Trading rules, limits, orders. Then
  `portfolio/playbook.md` (Exit rules) and `stocks/<TICKER>/thesis.md`.
- `bin/ledger strategies`, then `bin/ledger thread <id>` and `bin/ledger show <seq>` per entry.
  The newest `check` sets "since": its date and its `--goal_tests`.
- `strategies` shows OPEN from the `open`, filled or not. Each `open` or `adjust` with status
  pending and no later `fill`: ask the user whether it executed, at what price and quantity. Yes →
  log the `fill` first (step 7). No → ask whether it stands; withdrawn → `adjust --action "withdrawn"`.
- "Options and standing orders" table missing → ask what is open; create it: Strategy id | Instrument
  | Contracts | Cost | Order (type, price, duration) | Status (planned, placed, filled) | Fills at about | Sell-by date.
- A holding with no strategy → adopt it: `bin/ledger append --type open --strategy <ticker>-core
  --ticker <T> --action "hold, adopted" --origin "adopted" --evidence "holdings.md <date>"
  --reasoning "<thesis, or: no written thesis>" --early_disproof "<from thesis.md, or: none written>"`.
  An older `decision` → add `--ref <seq>`.

## 2. What changed
- Filings: `stocks/<T>/filings/INDEX.md` (filings on disk but no manifest → write it from the files
  present: form, filed date, file name, bytes). A filing may have landed since its newest row, or
  none is on disk → `/fin-protek:financial-fetch-filing <T>` (it downloads only what is missing).
  Figures: `bin/optcalc facts --facts stocks/<T>/filings/companyfacts.json --ticker <T>` and
  `extracted-financials.md`; open filing text only for risk factors, segments, covenants.
- ASK the user for today's price of each holding. Mark them user-supplied.
- Option legs only: `curl -sL -A "Mozilla/5.0" --compressed "https://cdn.cboe.com/api/global/delayed_quotes/options/<T>.json" -o "$TMP/cboe-<T>.json"`.
  State the feed timestamp. Feed fails and no broker quotes → write "value unknown"; no estimate.
- Due before the next check, from Outside this account: vests, plan purchases, deferred pay, a loan
  or mortgage reset, other dated terms. Date, shares or amount, and whether a window is open then.

## 3. Thesis test
Check each logged `early_disproof` condition against the new filings: INTACT, WEAKENED or BROKEN,
each with file:line. A falling price with the facts intact is NOT disproof. No written thesis →
say "not assessed" and route to `/fin-protek:financial-analyze-stock <TICKER>`.

## 4. Goal tests: read the map, never recompute
Read `portfolio/exposure-map.md`, whatever its headings: the result per goal, the income checks,
the income-linked bet against its limit, each limit's state (proposed or accepted), and the
questions owed. Map missing, or dated before the newest `fill` or a filing found in step 2 → say
"rerun the exposure map" (`/fin-protek:financial-exposure-map`) and skip this part. Otherwise copy
each result, with the map's date, into `--goal_tests`, against the last check: same, better or
worse. A failed test or a question owed → `/fin-protek:financial-conviction-test`; decide nothing here.

## 5. Position state (arithmetic in a `python3 -I` script; show the command)
- Shares: the map's limit state for each holding and bet. Over an accepted limit, or WEAKENED or
  BROKEN → hand to conviction-test (no verdict here). No limit on file → "no limit set".
- Each option leg: days to expiry and to sell-by; intrinsic and time value; contracts x 100 vs
  shares held (excess = net short, shortfall = unhedged shares); distance to each trigger.
- Each standing order: if it fills, what is left unprotected, and from what date.
- Each arrival (vest, plan purchase, deferred pay): while the map shows the income-linked bet above
  its ACCEPTED limit, the default is to sell it at the first date the window, pre-clearance and
  minimum holding period allow. A proposed limit or L_main owed → "pending your confirmation of
  <X>", no sale. Plan arithmetic: `/fin-protek:financial-conviction-test`.

## 6. Re-price option exit orders
`bin/optcalc value --chain "$TMP/cboe-<T>.json" --ticker <T> --expiry YYYY-MM-DD --strike K --kind P|C --at <trigger stock price> --on <date>`
A fixed limit on an option fills at a different stock price as time passes: re-price it each check,
and say past which stock level holding to expiry pays more than the limit. The exit rules are
hedge-design's (step 6 there); no order on a barred instrument or outside an open window.

## 7. Record (nothing closes before it happened)
- Each check: `bin/ledger append --type check --strategy <id> --ticker <T> --thesis_status
  "INTACT|WEAKENED|BROKEN|not assessed" --goal_tests "goal: result, map date, vs last check | rerun
  the exposure map" --evidence "file:line for every fact" --next_check "date, triggers"`.
- A new, re-priced or cancelled order, a sale (a vest sale too), a replaced leg: `--type adjust
  --status pending --action "..." --origin "AI-suggested" --reasoning "..."`.
- Only on the user's confirmed execution: `--type fill --strategy <id> --ref <order's seq>` with
  price and quantity.
- Only after the fill that ends the strategy, or an option expired worthless: `--type close
  --strategy <id> --proceeds_to "cash|<strategy id>|none"`. Option proceeds default to cash.
Update the table row to match. "Nothing to do" is a valid result: log the check and say so.

## 8. Next check and card
Set a calendar date (next results filing, the next item due from outside the account, or the
earliest sell-by date, whichever is sooner) and the trigger prices that bring the user back
sooner; put both in the check entry and the table. Then the card: a share fill or sale →
`/fin-protek:financial-sheet <TICKER> trade`; an option order placed, changed or filled, or a
strategy closed → `/fin-protek:financial-sheet <TICKER> position-check`. Not advice.

## Next
- Leg to replace or extend → `/fin-protek:financial-hedge-design <TICKER>`.
- A strategy closed → `/fin-protek:financial-review`. A failed goal test, shares over a limit or
  thesis WEAKENED → `/fin-protek:financial-conviction-test`.
