---
name: financial-review
description: Periodic outcome review of past decisions. Separates luck from skill, and price from thesis, so you reinforce only what actually worked. Use when revisiting matured or early-disproven decisions.
---
# Financial - Review

Start by running `bin/ledger verify`. If the chain is broken, stop and report it; the record
can't be trusted. Then `bin/ledger pending` to list decisions with no review yet.

For each pending decision, judge it, never by P&L alone:

1. **Horizon is years, but early disproof counts as bad.** A thesis whose pre-registered
   `early_disproof` BUSINESS conditions have triggered is a MISS now, regardless of the years
   left. You don't get to wait out a thesis that's already broken.
2. **Price is not thesis.** A falling price with the business facts INTACT is not disproof. It
   may mean the market is wrong (the whole point of the edge). Do not grade a sound, intact
   thesis as a failure just because the quote dropped.
3. **Offsets.** Weigh that a lower price may signal UNDERVALUATION (opportunity, not error), and
   credit DIVIDENDS: judge total return, not price alone. A flat price paying you to wait on an
   intact thesis is not a loss.
4. **Then the luck-vs-skill 2x2** (only once the outcome is genuinely judgeable):
   - sound decision + good result → skill_confirmed → REINFORCE (name the technique)
   - sound + bad (and not early-disproven) → unlucky → stay the course
   - unsound + good → LUCK → do NOT reinforce; flag the flawed process by name
   - unsound + bad / early_disproof triggered → process_failure → name the fix

Record each as a NEW append (history is never edited):
`bin/ledger append --type review --ref <seq> --outcome "..." --price_vs_thesis "facts vs price"
 --total_return "incl dividends" --attribution "skill_confirmed|unlucky|luck|process_failure|early_disproof_bad"
 --technique "reinforce or fix"`

Finally, surface PATTERNS across reviews: techniques repeatedly confirmed (lean in), repeatedly
failing (stop), and any habit rewarded by luck rather than skill. Output a short reinforce / fix /
watch list. No new trades here. This is learning, not acting.
