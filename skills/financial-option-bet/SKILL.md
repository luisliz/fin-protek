---
name: financial-option-bet
description: Decide whether one speculative bought call or bought put on a single ticker is worth its cost, paid from a sleeve the user accepts losing in full. Use when the user says "buy calls on X", "a put on X before earnings", or wants a directional option bet. Not for protecting a holding (financial-hedge-design), not for writing options, not for an option already open (financial-position-check).
---
# Financial - Option Bet: $ARGUMENTS

The first word of `$ARGUMENTS` is the TICKER; the rest is context. Bought options only; a written
option is out of scope: say so and stop. `$TMP` is the session scratchpad; fetch on the main thread.

## 1. Rules, goal and money first
Read `portfolio/holdings.md` and `portfolio/playbook.md` before anything else. Missing → run
`/fin-protek:financial-onboard`. Price date older than 30 days → confirm positions and cash first.
- **Trading rules**: STOP and name the rule when the TICKER is the employer, the user is an insider
  of it, or a ban on options covers it by ticker or by SCOPE: a class ban ("every financial
  company") covers every ticker in the class and any sector fund of it; test the class against the
  company's business in its filings, not its name. A covered ticker outside an open window → STOP.
  Never act on non-public information; "I see it from the inside" is a reason to stop.
- **Account and playbook**: a retirement account (Notes) → the user confirms it allows bought
  options. A bet that breaks a playbook Limit or Sizing rule stops here; name the rule.
- **The pot's test, read from the map** (`portfolio/exposure-map.md`; missing or older than
  `holdings.md` → `/fin-protek:financial-exposure-map` first): the long-run pot breaches its
  tolerance → no bet until `/fin-protek:financial-conviction-test` trims; its tolerance
  unconfirmed or not asked yet → no bet; name the confirmation owed.
- **Never spent**: cash set aside for a dated need (Notes), the minimum cash, and any money Goals
  assigns to a sum-by-a-date or income goal. The sleeve is a Deliberate bet, funded from the
  long-run pot only.
- **Sleeve**: the line `Speculative option sleeve: $__ per <period>, period starts YYYY-MM-DD (how
  set)` in `holdings.md` Deliberate bets. None → ask, and write it there dated. Spent = premium
  of every bet opened since the period start, open or closed, whatever it returned: the fill
  price, or the `open` entry's ask while pending (`bin/ledger strategies`, `bin/ledger thread
  <id>`, `bin/ledger show <seq>`). The premium is LOST the day it is spent. One idea takes at most
  HALF the sleeve unless the user overrides in writing (record it). REFUSE any bet that takes
  spend past the limit, conviction or not. The user must answer "yes, I accept losing all of it".

## 2. Document gate
No filings in `stocks/<TICKER>/filings/` → STOP, run `/fin-protek:financial-fetch-filing <TICKER>`.
No `thesis.md` → STOP, run `/fin-protek:financial-analyze-stock <TICKER>`. A fund: no bet (no
catalyst to cite). A call needs a thesis the filings support; a put, a dated, quantified risk
they disclose. Direction against the documents, or from a headline → stop and say why.

## 3. Catalyst test
Name ONE dated event (results, launch, maturity, ruling, lock-up expiry) whose date a document on
disk states, cited to file and location: the company's results-date announcement (press release
or 8-K) saved to `filings/`; a 10-Q, 10-K or prospectus naming the date; a proxy for a meeting
date; a regulator's date cited in a filing. A date inferred from last year's pattern is labelled
"inferred"; an inferred date alone → no bet. Choose an expiry AFTER the date with room for the
reaction. No documented catalyst before an affordable expiry → no bet.

## 4. Overlap check (from the map, never recomputed)
- A call on a name in a map cluster, or in the income-linked bet (a name sharing the driver of
  the main income, a property market, or a debt's rate, as "Outside this account" names it), adds
  to that bet. Its delta-adjusted notional (screen delta x 100 x contracts x stock price, by a
  `python3 -I` script; show the command) counts against that bet's ACCEPTED limit; over it → no
  bet. The limit is proposed or not on file → no bet; name the confirmation owed.
- A put on a held name is a hedge: `/fin-protek:financial-hedge-design <TICKER>`. Puts beyond shares held are a short bet.

## 5. Price test (program arithmetic only)
- `curl -sL -A "Mozilla/5.0" --compressed "https://cdn.cboe.com/api/global/delayed_quotes/options/<TICKER>.json" -o "$TMP/cboe-<TICKER>.json"`
- `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<TICKER>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<TICKER>.json"`
- `bin/optcalc screen --chain "$TMP/cboe-<TICKER>.json" --history "$TMP/px-<TICKER>.json" --ticker <TICKER> --max-ask <budget for this idea / 100>`;
  that cap buys one contract. Choose contracts after the screen: ask x 100 x contracts within budget.
No listed options, or a failed fetch and no broker quotes from the user → describe the structure,
write "cost unknown", and stop with no bet. Never fill in a number. Keep a row only if:
- expiry falls after the catalyst; need% is a move the stock has made (read hist_BE, hist_2x);
- hist_payoff is at or above 1.00 (it only rejects; after a long run every call passes);
- the spread is narrow relative to the ask and open interest is not thin; state both figures.
Repeat the program's caution: windows overlap and include past drift. Restate the leg (buy,
contracts, strike, expiry, ask, feed timestamp); the user cross-checks that quote with their broker.

## 6. Advisor pass and adversarial board
Save the screen table to `$TMP`. Dispatch `fin-protek:financial-advisor` once per candidate, in
parallel, each given ONLY ticker, direction, budget, screen file path; a REJECT ends it (name its
gate). Then `/fin-protek:financial-red-team-board` with the leg, catalyst and screen row, the
screen and `facts` output passed. One unrebutted point → no bet.

## 7. Exit rules, set before the buy
- **Profit rule**: price it with `bin/optcalc value --chain "$TMP/cboe-<TICKER>.json" --ticker <TICKER> --expiry YYYY-MM-DD --strike K --kind P|C --at PRICE --on YYYY-MM-DD`
  at the target stock level shortly after the catalyst; sell when the option reaches it.
- **Time stop**: catalyst passes without the move → sell within N trading days (state N).
- **Sell-by date**: before the final week. An in-the-money option left to expire is EXERCISED:
  a call buys, a put sells or shorts, 100 shares per contract.
- **Tax**: a gain on an option held under a year is often taxed at a short-term rate; ask your adviser.

## 8. Record, pending until the fill
A new bet is a new strategy, so `open`:
`bin/ledger append --type open --strategy <ticker>-<call|put>-<YYYY-MM-DD> --ticker <TICKER> --status pending
 --action "buy N <kind> K exp YYYY-MM-DD at ask X" --origin "AI-suggested" --sleeve "limit, spent, this bet"
 --reasoning "..." --evidence "file:location for every number; Cboe timestamp" --catalyst "event, date, source document"
 --counter_case "board's strongest point" --exit "profit rule, time stop, sell-by"
 --horizon_years "N" --early_disproof "BUSINESS facts, not a price move" --expectation "..."
 --confidence "low|med|high"`
Add the leg to "Options and standing orders" in `holdings.md`, status planned. On the user's
confirmed fill: `--type fill --strategy <same id> --ref <open seq>` with the price; row → filled.
A sound bet that loses is the expected case; review judges the sleeve, never one bet. No bet is
a valid result. Not advice. Last step: `/fin-protek:financial-sheet <TICKER> option-bet`.

## Next
- Bet logged → `/fin-protek:financial-position-check <id>` at the catalyst and the sell-by date.
- No bet → `/fin-protek:financial-find-ideas` for another candidate, or hold the sleeve in cash.
