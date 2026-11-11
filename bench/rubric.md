# Skill benchmark

Each skill gets a score out of 10. The score has three parts, and the lowest part limits the total.

1. **Mechanical gate** (`python3 bench/check.py`): any failure caps the skill at 8.
2. **Judged criteria** (below): ten criteria, each scored 0, 0.5, or 1 by a judge that did not write the skill.
3. **Scenario gate** (`bench/scenarios.md`): a skill that caused or allowed a missed "must" in a scenario run is capped at 7 until fixed.

A judge must quote the file and line for every deduction. A score with no quoted evidence does not count.

## Judged criteria

| # | Criterion | 1 point when |
|---|---|---|
| 1 | Trigger | The description says when to use the skill and when not to, in words a user would type. |
| 2 | Cold start | A session with no memory can follow it: it says what to read first and what to do when a file is missing or stale. |
| 3 | Executable | Every command, flag, file path, skill, and agent it names exists and works as written. |
| 4 | Complete | The steps cover the job in the description. No step relies on knowledge the skill does not give. |
| 5 | Guardrails | It enforces the workspace rules that apply: documents before opinions, no invented numbers, arithmetic by program, the adversarial board before a bullish conclusion, ledger entries through `bin/ledger`, pending until a confirmed fill. |
| 6 | Real users | It handles a user who has no limits set, no written thesis, a tax or employer restriction, or no option market, without stalling or guessing. |
| 7 | Consistent | Names, ledger entry types, file locations, and hand-offs match the other skills. |
| 8 | Output | It states what it produces, where it is written, and what the user is told. "Do nothing" is an allowed result. |
| 9 | Next step | It ends with one or two next commands chosen by outcome, and builds or offers the card when a strategy is decided. |
| 10 | Dense | No filler, no repeated rules, plain words, under 100 lines. |

## Rounds

Score every skill, fix what lost points, and score again with a judge that has not seen the previous
round. Stop when every skill is at 9 or above, or after four rounds. Report the round-by-round table,
including skills that did not reach 9.
