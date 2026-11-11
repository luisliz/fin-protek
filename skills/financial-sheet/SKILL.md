---
name: financial-sheet
description: Build a one-screen strategy card (local HTML) the moment a strategy is decided, or a longer sheet on request. Use after a hedge, option bet, buy, trim, sell or exit is logged, and when the user asks for "a card", "a one-pager" or "a page" on a thesis, hedge, option bet, trade, position check, or the whole portfolio. Not for deciding anything, and not for publishing or sharing: the page stays on the user's disk. The only skill that writes HTML.
---
# Financial - Sheet: $ARGUMENTS

The first word of `$ARGUMENTS` is a TICKER or `portfolio`; the rest is the topic: `thesis`,
`hedge`, `option-bet`, `trade` (also typed as `buy`, `trim`, `sell` or `exit`), `position-check`.
No topic → `thesis` for a ticker, `portfolio` otherwise. This skill decides nothing: a figure the
deciding skill or the exposure map did not produce is not on the card.

## 1. Gather sources, never fill gaps
Read only what the topic needs, and note each file's date:
- `portfolio/holdings.md` (always; missing → `/fin-protek:financial-onboard`; flag it stale when
  its price date is older than 30 days)
- `portfolio/exposure-map.md` for every goal test, limit and its state (portfolio, trade and
  position-check topics); missing or older than `holdings.md` → say so on the card
- `stocks/<TICKER>/thesis.md`, `stocks/<TICKER>/filings/`
- the ledger: `bin/ledger strategies`, `bin/ledger thread <id>`, and `bin/ledger show <seq>` for
  each entry the page cites, so fills and checks are not missed.
- option values: expiry rows use intrinsic value per leg (put: strike minus stock, call: stock
  minus strike, never below zero) x 100 x contracts, net of premium, computed in a script and
  shown per leg. Rows before expiry: `bin/optcalc value --chain FILE --ticker T --expiry YYYY-MM-DD --strike K --kind P|C --at PRICE --on YYYY-MM-DD`
  per leg. No chain on file → "value unknown". Never by hand.
Every figure carries its source and date. Label user-supplied prices as such. A missing figure
stays missing: print "not on file" and ask the user. Nothing is estimated.

## 2. The card (default): what each topic puts in the template
Copy `card-template.html` from this skill's base directory to `stocks/<TICKER>/<topic>-card.html`
(or `portfolio/<topic>-card.html`) and replace every `{{...}}`. Keep its layout and CSS; add no
sections. A sale across several tickers for one reason → one `portfolio/trade-card.html`, one
trade line per ticker; otherwise one card per ticker. It always leads with LIKELY_OUTCOME: the
most probable case with its base rate and source, even when that case is "the premium is lost".
Never put the best case first anywhere. Base rate by topic:
- hedge, option-bet: the share of past windows, from the `bin/optcalc screen` or `drawdown`
  output the deciding skill passed;
- thesis: the company's own guidance, or how often the early-disproof facts occurred in its filings;
- portfolio, position-check: of the three largest falls `book` printed for the goal, how many went
  deeper than its tolerance, with the history start date; income goal: the years of the last 3
  with cover under 1.00, from the `income` output;
- trade: "the order fills", with its condition (price, window, confirmation owed).
None on file → write "no base rate on file". Never a forecast in its place.

| Topic | Trade lines | Three figures, at most | The one table |
|---|---|---|---|
| hedge | each leg | cost, the most it can lose; floor or break-even; one bad-case result | stock at; shares; hedge; combined |
| option-bet | the leg | premium = max loss; break-even at expiry; result if the catalyst passes flat | stock at expiry; option; result |
| trade | each share order | shares and proceeds; weight after vs limit; tax if on file | stage, window, shares, weight after |
| position-check | each standing order | weight vs limit; thesis status; days to sell-by | trigger, fills at about, what it leaves |
| thesis | "No trade" or the logged one | bucket or "not assessed"; one filing figure; next check | early-disproof condition, status, source |
| portfolio | orders decided | the failing or tightest goal test; largest breach of an accepted limit, or "no accepted limits"; cash vs minimum | goal or cluster, value, test, result |
| portfolio, income goal | orders decided | ENOUGH: need, income, shortfall or surplus per year; weakest cover; top two payers' share | holding, income per year, low cover, share |

- **Goal results**: a tolerance unconfirmed, not asked, or declined never reads "no breach" or
  "fits": the cell reads "unconfirmed", "not asked" or "declined", with the worst replayed fall
  in dollars. An income goal is never judged by a price fall.
- **Trade lines**: as typed into a broker, each with its state: filled, placed, not placed,
  waiting (window opens <date>), or pending your confirmation of <X>.
- **Table**: at most 8 rows and 4 columns. Short cells so the card fits a 360px phone: at most
  7 characters in a 4-column table, 10 in a 3-column one ($48.2k, -31%, 03-19); dates longer
  than that go in the Dates line. A "no change" row on hedge, option-bet and trade tables only;
  combined result last; a total row's empty cells read "-". Colour swatches only on hedge,
  option-bet and result columns. State under the table what share results are measured against.
- **Exit plan**: each standing order with its price, the stock level where it fills, and what a
  fill caps or leaves unprotected. **Dates**: next check, decision date, sell-by. Absolute dates.
- A number that does not help the user act stays off. Over about 45 numbers → long sheet. A
  position-check after a share fill uses the trade layout, each line's state updated.

## 3. Long sheet, only when asked
`stocks/<TICKER>/<topic>-sheet.html` or `portfolio/<topic>-sheet.html`; decision first, then evidence:
- **Thesis**: verdict and bucket; falsifiable thesis; early disproof; filing figures with
  citations; red-team strongest points; ledger entry.
- **Hedge / option bet / trade**: the card's content plus the full scenario table, costs in $ and
  % of the position, and what the strategy misses (earnings, events, tracking error).
- **Portfolio**: each goal test first (income goals: enough, cover, concentration), then limit
  breaches with math, clusters with their evidence line, cash against the minimum, positions table.

## 4. Page contract (card and long sheet)
- Inline CSS only. No JavaScript, no external scripts. The web-font link ships commented out;
  uncomment it only when the user asks for the web fonts. The page reads correctly offline.
- Colors as CSS variables on `:root`, redefined under `@media (prefers-color-scheme: dark)`.
- Phone width: viewport meta, max-width container, 16px side padding, one column under 480px;
  long-sheet tables wider than 4 columns go in an `overflow-x: auto` wrapper.
- Footer: the data date, the sources with dates, what is left out (fees, tax), and "Not advice."

## 5. Check before finishing
- [ ] Each figure matches its source; totals and percentages recomputed in a script add up.
- [ ] Dates are absolute; no placeholder remains (`{{`, `__`, `TBD`, `TODO`, `XX`, empty cells).
- [ ] The first sentence under the title is the likely outcome; no goal reads "no breach" on an
  unconfirmed, unasked or declined tolerance.

## 6. Hand over
Tell the user the path and how to open it (`open <path>` on macOS, `xdg-open <path>` on Linux).
Never publish, upload, or share it; it holds private positions.

## Next
- Hedge, option-bet or trade card → `/fin-protek:financial-position-check <TICKER>` on its next
  check date or when an order fills. Thesis card → `/fin-protek:financial-analyze-stock <TICKER>`.
- Portfolio card → `/fin-protek:financial-exposure-map` after the next fill or filing.
