---
name: financial-hedge-design
description: Design downside protection for a holding the user is keeping. Use when the user asks "how do I protect", "should I buy puts on", "collar my position", or "insure my shares". Not for deciding whether to keep a holding (financial-conviction-test) or for a speculative option (financial-option-bet).
---
# Financial - Hedge Design: $ARGUMENTS

The first word of `$ARGUMENTS` is the TICKER; anything after it is context. `$TMP` is the session
scratchpad; run every fetch on the main thread. Strategy ids are lowercase (`<ticker>` below).
Price history, per ticker: `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<T>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<T>.json"`.

## 1. Gate, in this order
Read `portfolio/holdings.md` (missing → `/fin-protek:financial-onboard`; price date over 30 days
→ confirm shares and basis): Trading rules, Notes (tax, account type). Then `portfolio/playbook.md`,
`stocks/<TICKER>/thesis.md`, `bin/ledger strategies`, `bin/ledger thread <ticker>-core` (none →
open it first, as `/fin-protek:financial-position-check` does; a `<ticker>-hedge-*` exists → adjust).
`portfolio/exposure-map.md` (missing or older than the holdings price date → `/fin-protek:financial-exposure-map`
first): the goal this holding serves, its result, the holding's limit and whether it is accepted.
Above an ACCEPTED limit → the trim comes first (conviction-test), unless tax blocks it.
1. **Trading rules.** Options banned by the user (Trading rules table, Source user) → stop; offer the
   staged trim; record "options refused by the user". The name is the employer, or a ban covers
   options or hedging on it by ticker or by class ("any financial company") → no option on it.
   Re-check each ban's SCOPE against every instrument proposed, step 1b's fund included. Remaining
   choices: a staged trim in open windows; selling each vest or plan purchase; the employer's
   pre-arranged selling plan; step 1b. Outside an open window, date the plan to the window.
2. **Bucket** (thesis.md, else the latest ledger entry). Conviction → continue. Blank → "not
   assessed": send to `/fin-protek:financial-analyze-stock <TICKER>`; continue only on the user's
   explicit go-ahead, recorded as "designed without a written thesis". Drift or froth → a smaller
   position, owned by conviction-test; when Notes say tax blocks the sale, a hedge is valid: record
   the blocker and show the trim staged across tax years as the first row.
3. **Contract size.** Max contracts = shares held / 100, rounded down. More is a short position,
   not a hedge: name it a bearish bet and size it by budget. Under 100 shares → no single-name put;
   offer the staged trim or step 1b. Leftover shares beyond full contracts are unhedged; say how many.

## 1b. Index put (only when step 1 leaves it)
- Under an employer hedging ban it needs the employer's written confirmation that a broad-index
  option is outside the policy; until then record "scope to confirm", no cost, the staged trim first.
- Use the ETF (SPY, QQQ, IWM) for history, chain and contracts; the index (`_SPX` chain, Yahoo
  history `%5EGSPC`) only when the holding exceeds one index contract's notional.
- `bin/optcalc corr --history "$TMP/px-<TICKER>.json" --ticker <TICKER> --history "$TMP/px-<ETF>.json" --ticker <ETF>`:
  its falls table shows how far the fund fell in each of the stock's largest falls; it pays on a
  market fall, not a company one. Cap: contracts × 100 × fund price ≤ the holding's value.

## 2. Constraints before structures
Ask, don't assume:
- **Premium budget**: what the user can lose IN FULL over the horizon. Adding legs never raises it.
- **Horizon**: the date the protection must still be alive. The map's goal is a sum by a date → the
  expiry outlives that date, or the plan says plainly that it does not.
- **Must every share be kept?** Yes → no trimming, no written calls, and every long put is SOLD
  before expiry (an in-the-money put left to expire is exercised and sells 100 shares).
- **Account type** (Notes): a retirement account → the user confirms its option level allows each
  leg; a written put or call usually needs a higher level.

## 3. Match goal to instrument (NOT interchangeable)
- Full upside + a floor, willing to pay → PROTECTIVE PUT (IV is high once a selloff starts).
- Cheaper floor over a band → PUT SPREAD (buy a put, write a lower one, SAME expiry; the written
  put obliges the user to buy more shares below its strike).
- Near-free, OK losing upside → COLLAR (put funded by a written call; conflicts with "keep upside").
- Income + small cushion → COVERED CALL (caps gains; NOT uncapped risk, which is a naked call).
The strike is the DEDUCTIBLE, not a forecast: a put struck below "support" pays only if that belief is wrong.

## 4. Confirm the legs BEFORE any arithmetic
`curl -sL -A "Mozilla/5.0" --compressed "https://cdn.cboe.com/api/global/delayed_quotes/options/<TICKER>.json" -o "$TMP/cboe-<TICKER>.json"`
(`data.current_price`; `data.options[]` with `option` = TICKER+YYMMDD+C/P+strike×1000, `bid`, `ask`,
`iv`, `open_interest`). Cost a purchase at the ASK; state the feed timestamp; cross-check one
contract with the user's broker. **No chain** (fetch fails, a past date, no listed options, thin
open interest) → no premium: describe the structure, write "cost unknown", ask for broker quotes,
and keep the staged trim as the comparison. Restate every leg (buy or write, contracts, strike,
expiry, price) and get a yes. The expiry is a trading day; a later expiry costs more at one strike.

## 5. Report: every structure, same table
Measure P/L from TODAY'S PRICE, never cost basis. At each scenario price, hedged vs UNHEDGED:
premium in $ and % of position; floor; upside break-even; the price below which the hedge beats
doing nothing; the comparison with trimming (unless every share must be kept). Expiry rows are
intrinsic value per leg. Before expiry, `bin/optcalc value --chain "$TMP/cboe-<TICKER>.json" --ticker <TICKER> --expiry YYYY-MM-DD --strike K --kind P|C --at PRICE --on YYYY-MM-DD`
(an index put: its own chain and ticker); no option figure by hand. Base rate for the card:
`bin/optcalc drawdown --history "$TMP/px-<TICKER>.json" --ticker <TICKER>`, the share of past falls
that reached the strike within the horizon. Different expiries → path cases: (a) the early leg
expires worthless, then price falls; (b) price dips, the put gains, is not sold, and expires.
Place each expiry against the next results date from a document (the company's announcement or a
filing that states it), cited; otherwise label it "inferred" and show the covered and missed case.

## 6. Exit rules (part of the design)
For each bought option, price with `bin/optcalc value` and state: the sell rule (a limit at a
stated price, or a stock level); what a filled limit caps (the gain stops at the fill); the stock
level beyond which holding pays more than the limit; the review date and the sell-by date (before
expiry, so nothing is exercised). Never a stop-loss on insurance: a put losing value when it is not
needed is the premium working. Write each leg to "Options and standing orders", status planned.

## 7. Board, log, card
A put is a wasting asset; sizing fixes the disease. Before logging, run `/fin-protek:financial-red-team-board <TICKER> hedge <structure>`
(a no-hedge forced by a trading rule: process seat only). The hedge is its own strategy, id
`<ticker>-hedge-<YYYY-MM-DD expiry>`, or `<ticker>-hedge-none-<YYYY-MM-DD>` for a logged choice not to hedge:
`bin/ledger append --type open --strategy <ticker>-hedge-<YYYY-MM-DD> --ticker <TICKER> --status pending --action "buy N P K exp YYYY-MM-DD at ask X | no hedge" --origin "AI-suggested" --protects "<ticker>-core" --reasoning "..." --evidence "file:line; Cboe timestamp or cost unknown" --counter_case "board's strongest point" --exit "sell rule, cap, hold-beyond level, review date, sell-by" --constraint "trading rules, scope, tax" --horizon_years "N" --early_disproof "BUSINESS facts" --expectation "..." --confidence "low|med|high"`
A change to an existing hedge is `--type adjust`. `fill` only when the user confirms, with the price.
Last step: build the card, `/fin-protek:financial-sheet <TICKER> hedge`, with the drawdown base rate.

## Next
- After the fill → `/fin-protek:financial-position-check <TICKER>`.
- Not assessed → `/fin-protek:financial-analyze-stock <TICKER>`; drift with no tax block, or above an accepted limit → `/fin-protek:financial-conviction-test`.
