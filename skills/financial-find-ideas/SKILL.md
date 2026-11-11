---
name: financial-find-ideas
description: Entry point when the user wants ideas but has not named a trade ("what should I do with this cash", "find me a bet", "how do I diversify", "where do I put money for income", "which name in this cluster"). Screens a universe built from disk and routes each survivor, with the goal it serves, to one skill. Not for a verdict on a named ticker or "should I buy more of X" (financial-analyze-stock) or a hedge on a held name (financial-hedge-design). "Nothing passes" is a valid result.
---
# Financial - Find Ideas: $ARGUMENTS

`$ARGUMENTS` is an optional hint, never the answers to step 2. This skill screens and routes
only: no decision, no log, no bullish view, and no goal test or limit recomputed (the map measures).

## 1. Re-orient from disk first
- `portfolio/holdings.md`. Missing → stop and run `/fin-protek:financial-onboard`. Stale price
  date → confirm positions with the user first. Write down the **Goals** rows (kind, amount, date,
  tolerance, and the holdings or cash assigned), **Outside this account** (each item and its
  driver), **Trading rules** (each ban's ACTION and SCOPE; windows and pre-clearance with the
  tickers they cover), and the Notes' cash set aside for dated needs.
- `portfolio/exposure-map.md`, the one source for measurements. Missing or older than
  `holdings.md` → stop and run `/fin-protek:financial-exposure-map`. From it write down: each
  goal's test result; each limit and its state (accepted, or proposed and not yet accepted); the
  clusters with their evidence line; the income-linked bet; **Missing drivers**; **Questions owed**.
- `portfolio/playbook.md` (Limits, Sizing rules, Techniques to stop; missing → say so) and
  `bin/ledger strategies` for open strategies.

## 2. Intake: ask, don't assume
Ask for every item the user has not stated outright:
- **Goal** this money serves: one Goals row. A new goal → offer `/fin-protek:financial-onboard`
  to record it with its tolerance, and screen nothing for it until then.
- **Amount**, and whether it is money the user accepts losing IN FULL.
- **Horizon** as a date (a dated goal fixes it).
- **Instrument**: shares, fund, bought call or put (and how many contracts), or "you choose".
Available money = cash assigned to THIS goal, up to the amount. Never use cash set aside for a
dated need or money a Goals row assigns to another goal, whatever the user says in the moment;
state each excluded amount and its goal. Flag mismatches: a bought option is never "money I need
back" and never serves a dated, income or debt goal; a speculative sleeve is never the
diversification answer; protection goes to `/fin-protek:financial-hedge-design`.
From the map, never re-run: say first how this goal's test stands. A Questions owed item or an
unconfirmed tolerance for it → adds will be refused until settled; offer cash equivalents only.

## 3. Build the universe by construction
The universe is the union of these sources, and nothing else:
- names with filings on disk: `ls stocks/*/filings/` (skip `_TEMPLATE` and empty folders);
- names and funds the user nominates in this session, or that `reading/` or `holdings.md` names;
- cash equivalents (T-bills, a money-market fund), for any goal;
- for each driver class on the map's Missing drivers line (broad equity, bonds, cash-like): one
  broad fund. With none named on disk, describe the class and ask the user for the ticker their
  broker offers. Record the source of every fund ticker.
- each debt in Outside this account with a variable rate or a reset within 5 years: paying it
  down is a candidate use of cash, shown with its rate beside a T-bill yield the user supplies.
By goal: a sum due within 5 years → cash equivalents only; income → dividend payers from the
lists above plus cash equivalents. Never add a name from a headline, a reputation, or taste.
STATE the universe, with the source of each name, before screening it.

## 4. Screen (each gate rejects; none selects)
1. **Barred**: a candidate is barred only when the proposed instrument is a banned ACTION (options,
   short sales, purchases) AND the candidate is inside that ban's SCOPE (a named ticker, or a
   member of a banned class; a fund that holds the class is inside it for an options ban). A
   window or pre-clearance rule applies only to the tickers it covers.
2. **Overlap**: mark any candidate in a map cluster, in the income-linked bet, or sharing a driver
   with an Outside this account item (a REIT for a user who owns rental houses). A second ticker
   in the same bet is a size increase, routed as an add. The bet is over an ACCEPTED limit → drop.
3. **Playbook**: drop any candidate a playbook rule forbids.
4. **Documents**: no filings on disk → the idea stays, with Next = fetch-filing. No view yet.
5. **Options only** (bought call or put), on the main thread; `$TMP` = the session scratchpad.
   Ask cap X = `python3 -I -c "print(round(<money>/(<contracts>*100), 2))"`.
   - `curl -sL -A "Mozilla/5.0" --compressed "https://cdn.cboe.com/api/global/delayed_quotes/options/<T>.json" -o "$TMP/cboe-<T>.json"`
   - `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<T>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<T>.json"`
   - `bin/optcalc screen --chain "$TMP/cboe-<T>.json" --history "$TMP/px-<T>.json" --ticker <T> --max-ask X`
   A failed fetch → "cost unknown". hist_payoff rejects only: drop rows below 1.00, never rank by
   it. Drop rows with no catalyst documented before expiry (`/fin-protek:financial-option-bet`
   step 3 owns that rule). Cost: the Cboe ask and timestamp, or a user quote marked as such.
6. **Advisor triage**: save each screen table to `$TMP`. Dispatch `fin-protek:financial-advisor`
   once per candidate with filings on disk, all in parallel, in one message. Give each agent ONLY
   its own candidate: ticker, instrument, goal, budget, horizon, and the screen file path or
   `stocks/<T>/thesis.md`. A REJECT drops the candidate; name its gate in the output.

## 5. Route each survivor to exactly one skill, with its goal
| Survivor | Route |
|---|---|
| Shares of a new name, or a fund, filings or fund documents on disk | `/fin-protek:financial-analyze-stock <T> buy for <goal>` |
| Any name or fund with no documents on disk | `/fin-protek:financial-fetch-filing <T>` |
| Add to a held name or its cluster (overlap marks) | `/fin-protek:financial-analyze-stock <T> add for <goal>` |
| Speculative bought call or put (long-run pot only) | `/fin-protek:financial-option-bet <T>` |
| Cash equivalent | none: hold it; the user buys it at their broker |
| Debt paydown | `/fin-protek:financial-conviction-test` with the debt row |

## 6. Output
State the goal, available money, each excluded amount with its goal, horizon, universe, and any
Questions owed from the map. Then one table of at most five ideas:

| Instrument | Goal served | Why (catalyst cited or "inferred"; driver added) | Cost (source) | Adds or duplicates | Next command |
|---|---|---|---|---|---|

Cite every number to file and location, or the Cboe file and timestamp. "Nothing passes" means
no candidate survived gates 1-3: name the gate that stopped each; the money stays in cash or
T-bills. No trade, ledger entry or card; each routed skill logs its own decision. Not advice.

## Next
- Ideas listed: run the Next command of the one the user picks.
- Nothing passes: cash is the answer; stop. A Questions owed item → answer it, then
  `/fin-protek:financial-exposure-map`.
