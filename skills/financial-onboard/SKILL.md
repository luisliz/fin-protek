---
name: financial-onboard
description: First run in a new workspace, or "who is this investor" is not yet on file. Use when the directory has no CLAUDE.md or portfolio/holdings.md, holdings.md is in an older layout (no Goals, "Outside this account" or Questions owed), or the user says "set up", "start", "initialize fin-protek", or "my goals changed". Adds only what is missing, builds the programs, and records positions, goals, tolerances in the user's words, everything outside the account, trading rules and tax by interview. It runs no test and proposes no limit (financial-exposure-map does). Not for logging one trade or a price update; edit holdings.md or use financial-position-check.
---
# Financial - Onboard

One question: is this workspace set up, and who is this investor? This skill RECORDS. It runs no
test, proposes no limit and gives no view. Add what is missing; never overwrite or drop content.

## 1. Locate the plugin root
The plugin root is two levels above the "Base directory for this skill" that Claude Code printed.
Call it `$ROOT`; confirm `$ROOT/template/` and `$ROOT/ledger/build.sh` exist. Never hard-code a path.

## 2. Inventory, then fill gaps
Create only an absent or empty item, with `cp -n`; never `cp -R` over an existing directory.
- `CLAUDE.md` ← `$ROOT/template/CLAUDE.md`. Present → `diff` it against the template, show the
  sections that differ, and ask whether to append the missing ones. Never replace it.
- `portfolio/holdings.md` ← `$ROOT/template/portfolio/holdings.md`. Present in an older layout
  (any template section, column or field missing) → upgrade it:
  1. `cp -n portfolio/holdings.md portfolio/holdings-before-<YYYY-MM-DD>.md`.
  2. Rewrite it in the template's section order, each old value in its field: employer income →
     MAIN INCOME row; an old L → long-run pot Tolerance; an old L_job → L_main, "unconfirmed";
     windows and bans → Trading rules (no stated scope → "to confirm"); dated cash set aside → also
     a "sum by a date" Goal row; old limits keep their recorded state, else "proposed (older
     method)". A new field → "not asked yet"; a line with no field → Notes "Carried over".
  3. Prove nothing was lost: a `python3 -I` script lists each backup line whose figures or words
     are absent from the new file; place each one, then show the user that list and the `diff`.
     A carried line the user now contradicts goes to Notes "Corrections", never forward unchanged.
- `portfolio/playbook.md` ← `$ROOT/template/portfolio/playbook.md`; an existing one is left as is.
- `stocks/_TEMPLATE/` ← its files from `$ROOT/template/stocks/_TEMPLATE/`, one by one.
- `reading/`, `decisions/` → `mkdir -p`.

## 3. Build the programs
Skip a program that exists and runs. Otherwise `sh "$ROOT/ledger/build.sh" .` and
`sh "$ROOT/optcalc/build.sh" .`. No `ocamlopt` or `ocamlc` → record it missing, give the install
command (macOS `brew install ocaml`; Debian/Ubuntu `sudo apt install ocaml`; Fedora `sudo dnf
install ocaml`), and continue. When `bin/ledger` exists, run `bin/ledger verify` and report it.

## 4. Interview, one batch per message
Ask a batch, wait, write the answers into `portfolio/holdings.md`, then ask the next. A batch the
file already answers: show the values and ask whether they still hold; a changed answer → the new
value, with old, new and date under Notes "Corrections". "None" is an answer. Every answer has
one of three states: answered (confirmed or unconfirmed), "not asked yet", or "declined on <date>". No
default fills a gap; an unanswered question is never recorded as the user's choice.
1. **Positions**: ticker, shares, cost basis per share.
2. **Prices**: one per ticker, its date and source. Value and % by a `python3 -I` script over
   the table; show the command. A missing price stays blank.
3. **Cash and orders**: cash; cash set aside (amount, purpose, date or "standing"); open orders.
4. **Goals**: "What is each part of this money for?" One row per goal. Then "Which holdings and
   how much cash belong to each goal?"; money the user gives no other job is the long-run pot, and
   cash with no stated owner is asked about, never placed by default. Sum by a date: amount, date
   ("standing" for a reserve). Income: the income needed per year FROM THIS ACCOUNT (other
   household income goes under Outside this account). Debt payoff: balance, rate, terms date.
5. **Tolerance per goal**, in the user's words: long-run pot, the loss L they could bear; sum by
   a date, the loss on that sum (0 is an answer); income, the cut they could bear ("none" is an
   answer). State: a plain number → "confirmed on <date>"; a number with doubt ("40%, not sure")
   or words alone ("not much") → "unconfirmed"; refused → "declined on <date>". Never halve, round
   or replace the user's number; the exposure map shows it beside the replayed fall in dollars.
6. **Outside this account**, MAIN INCOME first: its source (employer and ticker, business,
   self-employment, rent), amount per year, stable or variable, and the driver it shares with the
   holdings (the employer's stock, the industry of the work, a property market). Then each other
   row: other household income, unvested or deferred stock (arrival dates, lost on leaving?), the
   employer plan's kind and terms, pension, property, each debt (balance, rate, fixed or variable,
   reset date), other accounts. With any main income, ask L_main: "What loss on THIS ACCOUNT could
   you bear in a year that income stopped?" Record words, number and state as in batch 5.
7. **Trading rules**: the employer's and the user's own, each ban with its action (options,
   hedging, short sales, purchases) and its scope: named tickers, or a class ("every financial
   company"). Windows, pre-clearance and minimum holding period, each with the tickers it covers.
8. **The user's own limits**: "Do you already hold yourself to any limit?" Each → Concentration
   limits, "set by the user on <date>". Propose none here.
9. **Conviction**: holdings the user would keep through a 50% drawdown, one-line reason each,
   under Deliberate bets; doubtful names as doubtful. No thesis on file is "not assessed".
10. **Tax**: per holding, whether tax on realized gains blocks selling (yes | no), the account
    (taxable | retirement), and the rate and holding period when the user knows them.

## 5. Questions owed
Write one line under "Questions owed" in `holdings.md` for each answer still "not asked yet" or
"unconfirmed", naming the skill that needs it (L_main, a tolerance, cash with no goal, a ban scope
"to confirm"). Remove a line only when its answer is recorded.

## 6. Working rules (say these)
- This workspace holds private positions: keep it out of public repositories. Never ask for
  account numbers, names, or anything identifying.
- No view on a company until its filings are read; no invented numbers; `bin/ledger` owns the
  record; only `/fin-protek:financial-review` changes the playbook. Not financial advice.

## 7. Output
This skill logs nothing, builds no card, and states no test result or limit. Show a status table,
one row each for `CLAUDE.md`, `portfolio/holdings.md`, `portfolio/playbook.md`,
`stocks/_TEMPLATE/`, `reading/`, `decisions/`, `bin/ledger`, `bin/optcalc`: existed / created /
upgraded (backup name) / missing (reason). Under it: each goal with its assigned money and
tolerance state, L_main and its state, then the Questions owed list.

## Next
- Portfolio recorded → `/fin-protek:financial-exposure-map` to measure each goal and propose limits.
- The user arrived with a question instead of a portfolio → `/fin-protek:financial-find-ideas`.
