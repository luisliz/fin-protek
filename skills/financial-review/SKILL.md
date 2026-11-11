---
name: financial-review
description: Review past decisions to separate skill from luck and price from thesis, then propose playbook changes the evidence supports. Use when a strategy has closed, a horizon has passed, an early-disproof fact may have hit, or the user asks "how did my calls do" or "what should I change in my rules". Not for checking an open position or order (financial-position-check), and no new trades. The only skill that edits portfolio/playbook.md.
---
# Financial - Review

## 1. Re-orient cold
- `bin/ledger verify`. Broken chain → stop and report it; the record cannot be trusted.
- No `decisions/ledger.log` → nothing has been decided; say "nothing to review" and stop.
- Read `portfolio/playbook.md` and `portfolio/holdings.md`. Missing → `/fin-protek:financial-onboard`.
- `bin/ledger strategies`; for each, `bin/ledger thread <id>`, then `bin/ledger show <seq>` for the
  fields of its entries. `bin/ledger pending` lists older `decision` entries with no review;
  `bin/ledger list` then `show` covers entries outside any strategy.
- Collect every `behaviour_proposal` field met on the way, with its seq.

## 2. What to review
- Every CLOSED strategy with no `review` entry in its thread, judged as the whole thread.
- Every OPEN strategy past its `horizon_years`, or with a filing on disk dated after its last
  `check` (or after its `open` when no check exists); read that filing in step 3 first.
- Every older `decision` from `bin/ledger pending` that meets either test.
- A trade (buy, sell, trim, option, order) with status pending and no `fill`: ask the user whether
  it executed, as `/fin-protek:financial-position-check` does. Yes → that skill logs the fill first.
  "Not executed" only when the user says so, or its stated window or decision date has passed; it
  gets no outcome grade. A keep, hold or no-add needs no fill: grade it at its horizon on total return.
- Every `behaviour_proposal` with no later `--scope "playbook"` review whose `--ref` names its seq.
Nothing qualifies → "nothing to review" is a valid result; say when the next horizon falls.

## 3. Facts, cited
- Total return since entry, by program: fetch `curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<T>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<T>.json"`
  (`$TMP` = session scratchpad), then a shown `python3 -I` script over its adjusted closes
  (`indicators.adjclose`, dividends included) from the entry date to today. No file → ask the user
  for prices and dividends, marked user-supplied. Never estimate.
- Disproof: read the filings dated after the entry. Missing → `/fin-protek:financial-fetch-filing <T>`.
- Every fact carries file:line or ledger seq.

## 4. Grade outcome and process separately
**Outcome**, on total return including dividends:
- a met `early_disproof` BUSINESS condition is BAD now, whatever years remain;
- a falling price with the facts INTACT is not bad: it is "not judgeable yet" until the horizon;
- option bets are graded as a sleeve: total premium paid against total proceeds across all closed
  bets, never one bet. A single lost premium is the expected case.
**Process**, by the entry's reason:
- Merit (a thesis decision): SOUND only when the entries show all of: documents read before the
  entry (cited in `--evidence`), the board run (`--counter_case`), horizon and early disproof
  pre-registered, size within the limits in force then (limits declined are not a gap), and status
  pending until a confirmed fill. Any other gap is UNSOUND.
- Size or goal (`--reason size|goal`, or `horizon_years n/a`): a trim or goal sale made by its rule
  is SOUND without a written thesis. Graded only on the rule: a confirmed tolerance or accepted
  limit in force (the exposure map of that date), the `book` re-run shown, pending until a fill.
- `--origin adopted` entries are not graded on process; they only record a holding found in place.
**Attribution**, one label:
- sound + good → skill_confirmed (name the technique)
- sound + bad → unlucky (a fact no one could see at entry; stay the course on process)
- unsound + good → luck (do NOT reinforce; name the flawed step)
- unsound + bad → process_failure (name the fix)
- outcome not judgeable or not executed → n/a
Record each as a NEW entry; history is never edited (an older `decision` takes only `--ref <its seq>`):
`bin/ledger append --type review --strategy <id> --ref <open seq> --outcome "good|bad|not judgeable|not executed"
 --process "sound|unsound: <missing step>" --price_vs_thesis "facts vs price" --total_return "<script output>"
 --attribution "skill_confirmed|unlucky|luck|process_failure|n/a" --evidence "file:line, user-supplied prices"`

## 5. Strategy reviewer: what the evidence says about the playbook
Run when at least one closed strategy was graded in step 4, or a `behaviour_proposal` is open.
1. Dispatch `fin-protek:financial-board-process` with the `bin/ledger thread <id>` output of every
   closed strategy, the grades from step 4, and the text of `portfolio/playbook.md`. Ask for an
   independent read of which playbook rules the evidence supports, contradicts, or never tested.
2. Engage its findings specifically. Then propose specific edits, one per line: section, the exact
   rule text added, changed or removed, the strategy ids behind it, and their count.
3. Rules for a proposal:
   - a technique is reinforced only by strategies graded skill_confirmed; luck never counts;
   - no rule changes on one outcome: a change needs at least THREE closed strategies; fewer only to
     REMOVE a rule that caused a process_failure;
   - fewer than three and no removal → no proposal; say how many more closed strategies it needs;
   - a `behaviour_proposal` is a rule set in advance for "Behaviours to watch": present it with N
     and X as the user set them; it needs the user's approval only, not three strategies.
4. The user approves or rejects each edit separately. Record the pass:
   `bin/ledger append --type review --ref <seqs of the strategy reviews and behaviour proposals> --scope "playbook"
    --approved "edits" --rejected "edits" --reasoning "board-process findings"`
   The program prints the new seq.
5. Apply only approved edits to `portfolio/playbook.md`, then append one Change log line per edit:
   date, section, the change, and "ledger seq <N>" of the entry above. Never edit an earlier Change log line.

## 6. Tell the user
Per decision: label, outcome, process gap if any, with sources. Then the playbook edits approved,
rejected, and those waiting for more evidence. This skill proposes no trade. Not advice.

## Next
- A holding the review doubts → `/fin-protek:financial-conviction-test`.
- A freed sleeve or a confirmed technique to apply → `/fin-protek:financial-find-ideas`.
