---
name: financial-red-team-board
description: Convene an adversarial board of independent seats (short-seller, forensic accountant, credit analyst, macro and portfolio, process auditor) against a stated decision before it is recorded. Use before any bullish conclusion, buy, add, hedge, speculative option, sell or trim, or exposure/conviction verdict, and when the user asks "argue against this" or "what am I missing". Not for a decision not yet stated; ask for it first.
---
# Financial - Red Team Board: $ARGUMENTS

The first word of `$ARGUMENTS` is a TICKER or `portfolio`; the rest is the decision. No decision
stated → ask for it before dispatching. One adversary shares the main agent's blind spots;
independent seats with different inputs do not. This skill alone chooses the seats; callers name
the decision, never a seat count. Seats reason; programs calculate.

## 0. Pre-flight (main thread)
- Read `portfolio/holdings.md` (missing → `/fin-protek:financial-onboard` first): the **Goals**
  the decision touches, **Outside this account**, **Trading rules**. Note whether
  `portfolio/playbook.md` and `portfolio/exposure-map.md` exist, and the map's date.
- TICKER decision with no filings on disk → STOP and run `/fin-protek:financial-fetch-filing
  <TICKER>`. `portfolio` decisions skip this check.
- **Programs first.** Seats have no network, run no program and compute no ratio, weight or
  return. The caller passes the printed output it already ran; run here whatever a chosen seat
  needs and the caller did not pass: `bin/ledger list`, `bin/ledger strategies`;
  `bin/optcalc facts`, `book`, `corr`, `income`, `drawdown` as the decision requires; and one
  `python3 -I` ratio script over the `facts` output (margins, free cash flow, coverage, net debt
  over EBITDA, dividend cover, and valuation multiples at the user-supplied price and its date).
  Show each command. A price the user has not supplied → the short-seller is told "valuation not
  tested". A trade or portfolio verdict with no `book` output → tell the process seat.

## 1. The seats
Dispatch each as `fin-protek:<agent name>`. Give each seat ONLY what its row allows; this table is
the one statement of the isolation rule. "Output" means printed program output, as text.

| Seat (agent) | Attacks | Allowed to see |
|---|---|---|
| Short-seller (`financial-red-team`) | the company: valuation, demand, supply chain, the load-bearing assumption | ticker, decision, thesis, extracted numbers, `stocks/<TICKER>/`, `reading/`, `facts` and ratio output, user-supplied price and date |
| Forensic (`financial-board-forensic`) | the numbers: checks them line by line against the filing text and `facts` output, then earnings quality | ticker, `stocks/<TICKER>/filings/`, `facts` output; it opens `extracted-financials.md` and `thesis.md` only after its own table is written |
| Credit (`financial-board-credit`) | the balance sheet as a lender reads it; dividend safety; the closed-market case | ticker, `stocks/<TICKER>/filings/`, `facts`, ratio and `income` output; never `extracted-financials.md` or the thesis |
| Macro (`financial-board-macro`) | the fit: regime, the map's clusters against their evidence, Outside this account, one more ticker on a bet | decision, `holdings.md`, `playbook.md`, `exposure-map.md`, `book`, `corr`, `drawdown` and `income` output, `stocks/*/thesis.md`, `reading/` |
| Process (`financial-board-process`) | the decision and its makers, the main agent included | decision, proposed action, ledger and `book` output, `holdings.md`, `playbook.md`, `exposure-map.md`, `thesis.md` |

## 2. Which seats run (first matching row)
- **Sizing only** (a trim to a limit, a sale to fund a goal, a refusal to add, a no-hedge forced
  by a trading rule): process; add macro for a sale to fund a goal.
- **Buy, add, hedge design, speculative option**: all five.
- **Sell, trim or no-add on the merits**: short-seller in inverted mode (it argues for keeping),
  macro, process.
- **`portfolio` decisions** (exposure map, conviction test): macro, process.
- **Default** (a thesis, a keep or hold on the merits, anything else): short-seller, forensic, process.
- **Add credit** to any row but sizing only when an income goal depends on the holding, or the
  decision rests on a dividend, on debt, or on a bank, REIT or utility. A `portfolio` decision
  adds credit for the largest member of each cluster an income goal depends on, and of the
  largest cluster when that cluster is banks, REITs or utilities.
State which seats run and why in one line before dispatching.

## 3. Dispatch
- Dispatch the chosen seats IN PARALLEL, in one message, each in its own context. Seats NEVER see
  each other's output; never relay one seat's findings into another's prompt.
- Every prompt repeats the standing rules: documents on disk and the output given only; cite
  file + line for every figure; compute no ratio, weight or return, and ask by name for any figure
  not given; never invent a price; do not be balanced; report only conclusions.
- **Seats cannot be dispatched as separate agents** (no agent tool, or a context that forbids
  it): run only the chosen seats, each as its own pass, in this order: forensic, credit,
  short-seller, macro, process. Give each pass only its row's inputs. Record `board: seats not
  independent` in `--evidence` and cap `--confidence` at low.

## 4. Answer the board
- **Each seat's strongest point**: rebut it with a citation (file + line) or concede and say how
  the thesis, size, or structure changes.
- **Figures asked for by name**: run them by program or script now and answer with the output.
- **Forensic mismatches** are corrections first: fix `extracted-financials.md` and `thesis.md`
  from the filing before arguing anything that rested on the wrong figure. No extraction on disk →
  write the forensic table there.
- **Disagreements**: list where seats contradict each other; say which side the documents support.
- **Unanswered**: state plainly which objections you could not rebut.
- **Never average the seats into a vote.** One unanswered fatal point outweighs four quiet seats.
  Confirming the prior without engaging a seat is a FAILURE.

## 5. Write and record
- Write `stocks/<TICKER>/board-YYYY-MM-DD-<caller>.md` or `portfolio/board-YYYY-MM-DD-<caller>.md`
  (`<caller>` = the calling skill's short name, such as `analyze-stock`, or `direct`): the
  decision, seats run and whether independent, each seat's strongest point, and the answer or
  "UNANSWERED". Tell the user the verdict: proceed, change, or stop, and why.
- **Called from another skill** → return `counter_case`, `early_disproof`, the seats run, whether
  independent (the confidence cap applies to the caller's entry) and the file path. Do not log.
- **Called directly** → log through the program: `bin/ledger append --type open|check|adjust
  --strategy <ticker>-core --ticker <TICKER> --action "..." --origin "AI-suggested"
  --counter_case "<strongest UNANSWERED objection, with its seat>" --early_disproof "<earliest
  business facts, filing lines, macro releases; not a price move>" --horizon_years "N"
  --expectation "..." --confidence "low|med|high" --evidence "seats run; file:line"
  --asof YYYY-MM-DD --status pending`. A name with no strategy takes `--type open`; a
  `portfolio` decision uses `--strategy portfolio-<goal>`.
- **A fatal objection stands unanswered** → no action. Log the rejection (`--action "rejected:
  <seat point>"`) when called directly, and stop. Not financial advice.

## Next
- Called from a skill → return to it with the findings.
- Called directly, strategy logged → build the card now: `/fin-protek:financial-sheet <TICKER> thesis`
  (or `/fin-protek:financial-sheet portfolio`). A seat named a missing document →
  `/fin-protek:financial-fetch-filing <TICKER>`, then rerun the board.
