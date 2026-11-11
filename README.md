# fin-protek

A Claude Code plugin for a self-directed investor whose edge is risk recognition, not return
prediction. Claude reads the real SEC filings, argues against its own thesis with an independent
red team, maps hidden overexposure, and records every decision in a tamper-evident ledger.

The process is part-time by design. You can leave it for months, drop in new documents, and run
one command.

## What you get

| Command | What it does |
|---|---|
| `/fin-protek:financial-fetch-filing TICKER` | Downloads the 10-K, 10-Q, 8-K, 20-F, or S-1 from EDGAR, strips it to text, and extracts cited figures. |
| `/fin-protek:financial-analyze-stock TICKER` | Builds a falsifiable thesis from the filings, then sends it to the red team before any bullish conclusion. |
| `/fin-protek:financial-exposure-map` | Clusters holdings that share an end market, supply chain, style, or macro driver. Each cluster counts as one bet. |
| `/fin-protek:financial-conviction-test` | Sorts every holding into conviction, drift, or froth by one question: would you hold it through a 50% drawdown? |
| `/fin-protek:financial-hedge-design TICKER` | Matches a protection instrument (protective put, put spread, collar, covered call) to your goal and budget, using a real option chain. |
| `/fin-protek:financial-review` | Grades past decisions on reasoning, separating luck from skill and price from thesis. |

The plugin also ships:

- `fin-protek:financial-red-team`, a subagent that argues only the bear case in its own context.
- `ledger/`, the source of a small OCaml program that owns the decision record.
- `template/`, a starter workspace with the operating rules (`CLAUDE.md`) and the folder layout the commands expect.

## Requirements

- Claude Code
- OCaml, to build the ledger (`brew install ocaml` or `apt install ocaml`)
- `curl` and `python3`, for fetching and stripping filings

No market data subscription and no API key. EDGAR and the Cboe delayed option feed are free.

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

1. Clone this repository.

   ```sh
   git clone https://github.com/luisliz/fin-protek.git
   ```

2. Copy the template to a new workspace.

   ```sh
   cp -R fin-protek/template ~/portfolio
   ```

3. Build the ledger into the workspace.

   ```sh
   sh fin-protek/ledger/build.sh ~/portfolio
   ```

4. Fill in `~/portfolio/portfolio/holdings.md`: your positions, the date of the prices, and your
   concentration limits.

5. Start Claude Code in the workspace.

   ```sh
   cd ~/portfolio && claude
   ```

`CLAUDE.md` loads at the start of every session and sets the rules listed below.

## First analysis

Run these in order for one ticker.

1. `/fin-protek:financial-fetch-filing MSFT` puts the filings in `stocks/MSFT/filings/`.
2. `/fin-protek:financial-analyze-stock MSFT` extracts the numbers, forms a thesis, runs the red
   team, and writes `stocks/MSFT/thesis.md`.
3. `/fin-protek:financial-exposure-map` shows whether the name is a new return driver or a second
   ticker on a bet you already hold.
4. `/fin-protek:financial-conviction-test` decides keep, trim, or sell across the whole portfolio.
5. `/fin-protek:financial-hedge-design MSFT` applies only to conviction holdings you want to insure.
6. `/fin-protek:financial-review` runs months later, against the decisions the ledger holds.

## Workspace layout

```
CLAUDE.md                      operating rules, loaded every session
portfolio/holdings.md          positions + concentration limits
stocks/<TICKER>/filings/       10-K, 10-Q, 8-K, prospectus
stocks/<TICKER>/reading/       articles about that name
stocks/<TICKER>/thesis.md      current belief on that name
reading/                       portfolio-wide and macro reading
decisions/ledger.log           decision record, written only by bin/ledger
bin/ledger                     the ledger program
```

## The ledger

A language model cannot be trusted to keep a file append-only; it can rewrite or drop history.
A program owns the decision record instead.

- `bin/ledger append --type decision ...` adds an entry. The program opens the file in append mode and never rewrites it.
- `bin/ledger append --type review --ref N ...` records an outcome as a new entry. Past entries never change.
- `bin/ledger verify` recomputes the hash chain and reports any edit, deletion, or reorder.
- `bin/ledger list`, `show N`, and `pending` are read-only views.

Each decision carries a horizon in years, the business facts that would disprove it early, a
falsifiable expectation, and a confidence level. Those fields make the later review honest.

NOTE: the chain uses MD5. It detects accidental or careless edits by a model. It does not stop a
person who rewrites the whole file and recomputes every hash.

## Rules the workspace enforces

- Claude gives no view on a company whose filings it has not read.
- Every number cites a file and a line. Claude asks for a missing number instead of estimating it.
- There is no live price feed. You supply prices, and Claude marks them as user-supplied.
- A bullish conclusion requires a red-team pass first.
- A falling price with the business facts intact does not disprove a thesis. Business facts that break the thesis count against it at once, before the horizon ends.
- A good outcome from an unsound decision is luck, and the review does not reinforce it.

## Limits

- SEC registrants only. The fetch command reads SEC EDGAR, so a company with no SEC filings is out of scope.
- Option chains come from a delayed feed. Check one contract against your broker before trading.
- The plugin places no trades and connects to no brokerage account.
- The exposure map is qualitative. It does not compute statistical correlations.

## Disclaimer

This is not financial advice. The plugin is a sparring partner that makes you defend a trade. It
cannot see your full balance sheet or your tax situation, and its output can be wrong.

## License

MIT. See `LICENSE`.
