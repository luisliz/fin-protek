# fin-protek

A Claude Code plugin for a self-directed investor whose edge is risk recognition, not return
prediction. Claude reads the real SEC filings, argues against its own conclusions with an
independent board, finds holdings that are the same bet, does the arithmetic with a program, and
records every decision in a tamper-evident ledger.

The process is part-time by design. You can leave it for months, drop in new documents, and run
one command.

## Commands

Each command answers one question. None answers another's.

| Command | The question it answers |
|---|---|
| `/fin-protek:financial-onboard` | Is this workspace set up, and who is this investor? |
| `/fin-protek:financial-find-ideas` | Given this goal and this money, which paths are worth a look? It screens and routes; it never decides. |
| `/fin-protek:financial-fetch-filing TICKER` | Are the real documents on disk? Fetches the 10-K, 10-Q, 8-K, 20-F, 6-K, or S-1 from EDGAR. |
| `/fin-protek:financial-analyze-stock TICKER` | What is the thesis for this company, from its filings? It also decides whether you may add to a holding. |
| `/fin-protek:financial-red-team-board TICKER` | What is the strongest case against this conclusion? |
| `/fin-protek:financial-exposure-map` | Which holdings are the same bet? |
| `/fin-protek:financial-conviction-test` | Which holdings do I keep, trim, or sell? |
| `/fin-protek:financial-hedge-design TICKER` | How do I insure a holding I am keeping? |
| `/fin-protek:financial-option-bet TICKER` | Is this one speculative option worth its cost? |
| `/fin-protek:financial-position-check TICKER` | What changed on my open strategies and their orders? |
| `/fin-protek:financial-review` | Which past decisions were skill, and which were luck? It proposes changes to your playbook. |
| `/fin-protek:financial-sheet TICKER` | What does the decided strategy look like on one card? |

A command that logs a decision ends by building its card. Every command names its next step.

## What else ships

- **The board.** Five subagents, each in its own context, each reading only documents on disk.
  `financial-red-team` argues the case against the decision (for a proposed sale, the case for
  keeping). `financial-board-forensic` recomputes the filing numbers itself.
  `financial-board-credit` reads the balance sheet as a lender. `financial-board-macro` tests the
  fit with the rest of your holdings. `financial-board-process` audits the decision and the people
  making it, Claude included.
- **`financial-advisor`.** A subagent that returns BUY-CANDIDATE or REJECT for one candidate.
  Rejecting is the common result.
- **`ledger/`.** The source of a small OCaml program that owns the decision record.
- **`optcalc/`.** The source of a small OCaml program for the arithmetic: option screens and
  values, a stock's largest falls, and whether two holdings fell together.
- **`template/`.** A starter workspace: the operating rules (`CLAUDE.md`), the holdings file, the
  playbook, and the folder layout.
- **`bench/`.** The rubric, scenario list, and mechanical check used to score the commands.

## Goals, and what sits outside the account

The plugin does not assume one goal and one risk number. The holdings file records your goals,
each with its own tolerance and the money assigned to it:

- a long-run pot, tested by replaying its holdings through their own history;
- a sum needed by a date (a house deposit, a loan reset), tested on its own and never blended in;
- an income you live on, tested three ways: is it enough, is each dividend covered, how concentrated is it;
- a debt you may pay down.

It also records what sits outside the account and shares a driver with your holdings: your main
income (an employer, a business, self-employment), unvested or deferred stock, an employee
purchase plan, a pension, property, and debt. One extra question follows from it: the loss you
could bear on this account in a year your main income stopped.

- The exposure map reports the income-linked bet first: holdings that share your income's driver.
- No command proposes an instrument your employer bars, or a trade outside an open window. A ban
  can cover named tickers or a whole class of companies.
- While the income-linked bet is above its accepted limit, the default for each vest and plan
  purchase is to sell it.
- An answer is one of three things: answered, not asked yet, or declined. No default fills a gap.
- A limit is proposed until you accept it. A proposed limit can block a purchase; it never
  schedules a sale.
- The plugin gives no tax guidance. It records what you tell it about holding periods.

## Who does what

Each procedure has one owner, so two commands never disagree about a number.

- **Onboarding records** what you tell it. It runs no test and proposes no limit.
- **The exposure map measures.** It alone runs each goal's test and writes the results to
  `portfolio/exposure-map.md`.
- **The conviction test decides** keep, trim, or sell from that file.
- **The position check monitors** open strategies and orders against it.

## Requirements

- Claude Code
- OCaml, to build the two programs (`brew install ocaml` or `apt install ocaml`)
- `curl` and `python3`, for fetching and stripping filings

No market data subscription and no API key. EDGAR, the Cboe delayed option feed, and a free daily
price endpoint supply the data.

## Install

1. Add this repository as a plugin marketplace. Run this inside Claude Code:

   ```
   /plugin marketplace add luisliz/fin-protek
   ```

2. Install the plugin:

   ```
   /plugin install fin-protek@fin-protek
   ```

## Set up a workspace

The commands read and write files in the directory where you start Claude Code. Keep that
directory private; it will hold your positions.

1. Make an empty private directory.
2. Start Claude Code in it.
3. Run `/fin-protek:financial-onboard`.

What onboarding does:

- Copies the template files it finds missing. It never overwrites a file that has content.
- Builds the two programs into `bin/`.
- Interviews you: positions and their price date, cost basis, your goals and the money assigned
  to each, what sits outside the account, trading rules, and where tax blocks a sale.
- Lists the questions still owed, runs `bin/ledger verify`, and sends you to the exposure map.

To build the programs by hand, run these from the workspace, with `PLUGIN` set to the plugin directory:

```sh
sh "$PLUGIN/ledger/build.sh" .
sh "$PLUGIN/optcalc/build.sh" .
```

## A first pass

1. `/fin-protek:financial-onboard` records who you are, what you hold, and what each goal is.
2. `/fin-protek:financial-exposure-map` tests each goal, shows which holdings are one bet, and
   proposes limits for you to accept.
3. `/fin-protek:financial-conviction-test` decides keep, trim, or sell. A sale has one of three
   reasons: merit, size, or funding a goal. A holding with no written thesis is "not assessed"
   and goes to step 4; it is never sold for that reason alone.
4. `/fin-protek:financial-fetch-filing MSFT`, then `/fin-protek:financial-analyze-stock MSFT`,
   write the thesis from the filings and run the board.
5. `/fin-protek:financial-hedge-design MSFT` applies to a holding you keep and want to insure.
6. `/fin-protek:financial-position-check` re-tests open strategies after a fill or a new filing.
7. `/fin-protek:financial-review` runs months later, on strategies that have closed.

Start from `/fin-protek:financial-find-ideas` instead when you arrive with a question ("what do I
do with this cash") rather than a portfolio. "Nothing passes" is a valid answer.

## Workspace layout

```
CLAUDE.md                      operating rules, loaded every session
portfolio/holdings.md          positions, goals, what sits outside the account, limits, orders
portfolio/playbook.md          your own rules; changed only by the review command
portfolio/exposure-map.md      the latest goal tests, one-bet clusters, and proposed limits
stocks/<TICKER>/filings/       10-K, 10-Q, 8-K, 20-F, 6-K, prospectus
stocks/<TICKER>/reading/       articles about that name
stocks/<TICKER>/thesis.md      current belief on that name
reading/                       portfolio-wide and macro reading
decisions/ledger.log           decision record, written only by bin/ledger
bin/ledger                     the ledger program
bin/optcalc                    the arithmetic program
```

## The ledger

A language model cannot be trusted to keep a file append-only; it can rewrite or drop history.
A program owns the decision record instead.

- `bin/ledger append --strategy ID --type open|fill|check|adjust|close|review ...` adds an entry.
  The program opens the file in append mode and never rewrites it.
- `bin/ledger verify` recomputes the hash chain and reports any edit, deletion, or reorder.
- `bin/ledger strategies` lists each strategy as OPEN or CLOSED. `bin/ledger thread ID` prints one
  strategy's entries in order. `list`, `show N`, and `pending` are further read-only views.

A position is a strategy with a life: open, fill, checks, adjustments, close, review. Reading one
thread tells the story of a position. A hedge and the shares it protects are two strategies.

The program refuses an entry that has no fields, an empty value, a strategy step with no strategy
id, a fill or review with nothing to refer to, or a decision with no action. A proposed trade is
logged as pending; the fill is its own entry; a strategy closes only after the fill that ends it.

NOTE: the chain uses MD5. It detects accidental or careless edits by a model. It does not stop a
person who rewrites the whole file and recomputes every hash.

## The arithmetic program

- `bin/optcalc screen` lists affordable, liquid bought calls and puts and compares each
  break-even with the stock's own history.
- `bin/optcalc value` models an option's price at a stock level on a date, for setting exit orders.
- `bin/optcalc drawdown` reports a stock's largest falls and how long each took to recover.
- `bin/optcalc corr` reports whether two holdings moved together, year by year, and what each did
  during the other's largest falls.
- `bin/optcalc book` replays a set of holdings at today's mix through their shared history. It
  prints the worst falls in dollars, the evidence for which holdings are one bet, and how far the
  holdings must be scaled back to fit a tolerance.
- `bin/optcalc facts` prints a company's multi-year figures from the SEC's structured facts file,
  with a citation per cell, so an annual report is not re-read to rebuild the same table.
- `bin/optcalc income` compares the income a set of holdings pays with what you need, and reports
  dividend cover and how concentrated the income is.

The program refuses a price history that is not daily, and prints NOT FOUND where a figure is
missing. It never estimates.

## Rules the workspace enforces

- Claude gives no view on a company whose filings it has not read.
- Every number cites a file and a line, or the program run that produced it. Claude asks for a
  missing number instead of estimating it.
- There is no live price feed. You supply prices, and Claude marks them as user-supplied.
- A bullish conclusion requires a board pass first.
- Claude never does option, correlation, or ledger arithmetic itself. The programs do.
- "These two offset each other" is a claim to test with price history, never to accept.
- A falling price with the business facts intact does not disprove a thesis. Business facts that
  break the thesis count against it at once, before the horizon ends.
- A good outcome from an unsound decision is luck, and the review does not reinforce it. No rule
  in your playbook changes on a single outcome.

## How the commands are tested

`bench/rubric.md` scores each command out of 10 on ten criteria, by a judge that did not write it.
`bench/check.py` checks what a program can check: every command, flag, skill, and agent a command
names must exist. `bench/scenarios.md` describes invented investors; an analyst follows the
commands for each one using only the filings and prices that existed on a past date, and a missed
requirement is charged to the command that should have caught it.

```sh
python3 bench/check.py
```

## Limits

- SEC registrants only. A company with no SEC filings is out of scope. Funds have no annual
  report of the kind the analysis expects; the exposure map looks through a fund only when you
  supply its holdings.
- Option chains come from a delayed feed. Check one contract against your broker before trading.
- No option chain exists for a past date, so a past hedge cannot be priced.
- The history score in the option screen overlaps its windows and includes past drift. It flatters
  every call on a stock that has had a long run. Use it to reject, never to select.
- A low long-run correlation does not mean two holdings offset each other in a selloff.
- A replay shows what holdings did in the past at today's sizes. It is not a forecast, and a
  crash before the first date in the price history is not in it.
- Dividend cover is a weak predictor of a cut, and a low year can come from a one-off payment.
- The structured facts file carries the tags each company chose. A mis-tagged figure is possible;
  the board's forensic seat checks figures against the filing text.
- No goal kind yet fits money drawn monthly for an unknown period, such as living costs between jobs.
- The plugin places no trades and connects to no brokerage account.

## Disclaimer

This is not financial advice. The plugin is a sparring partner that makes you defend a trade. It
cannot see your full balance sheet or your tax situation, and its output can be wrong.

## License

MIT. See `LICENSE`.
