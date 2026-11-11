---
name: financial-hedge-design
description: Design downside protection for a specific holding. Use only AFTER conviction is established, never to rescue a position that should be sold.
---
# Financial - Hedge Design: $ARGUMENTS

The first word of `$ARGUMENTS` is the TICKER; anything after it is context.

## 1. Gate: is this a position worth insuring?
Read `stocks/<TICKER>/thesis.md` and `portfolio/holdings.md` (confirm share count + basis with the
user; holdings may be stale).
- Bucket = conviction → continue.
- Bucket = drift/froth → STOP, recommend selling; a hedge on the wrong position is rent on a risk
  the user already rejected.
- Thesis blank or missing → SAY SO. Offer `/fin-protek:financial-conviction-test` first. Continue
  only on the user's explicit go-ahead, and record in the ledger entry that the hedge was designed
  without a written thesis.

## 2. Constraints before structures
Ask, don't assume:
- **Premium budget**: the amount the user can lose IN FULL over the horizon. Every structure is
  checked against it; adding legs never silently raises it.
- **Horizon**: the date the protection must still be alive.
- **Must the user keep every share?** If yes: no trimming, no written calls (shares can be called
  away), and every long put is SOLD before expiry. An in-the-money put left to expire is
  auto-exercised and sells 100 shares.

## 3. Match goal to instrument (NOT interchangeable)
- Full upside + a floor, willing to pay → PROTECTIVE PUT (premium; IV is HIGH right after a
  selloff starts, so mid-decline protection is expensive).
- Cheaper floor over a band, OK being unprotected below it → PUT SPREAD (buy a put, write a lower
  one, SAME expiry; the written put is an obligation to buy more shares below its strike).
- Cheap/near-free, OK losing upside → COLLAR (put funded by selling a call; deletes upside.
  Flag the conflict with "keep upside").
- Income + small cushion, OK capping gains → COVERED CALL (caps upside; NOT uncapped risk,
  which is a naked call).
- Puts beyond the share count are NOT a hedge. They are a short position. Name it as a bearish
  bet and size it by budget.

The strike is the DEDUCTIBLE (the loss the user keeps), not a forecast. A support level says where
the user thinks price stops; a put struck below it only pays if that belief is wrong.

## 4. Confirm the legs BEFORE any arithmetic
Never invent a quote. Pull the full chain yourself from the Cboe delayed feed:
`curl -sL -A "Mozilla/5.0" --compressed "https://cdn.cboe.com/api/global/delayed_quotes/options/<TICKER>.json" -o "$TMP/chain.json"`
(`data.current_price`, and `data.options[]` with `option` = TICKER+YYMMDD+C/P+strike×1000, `bid`, `ask`,
`iv`, `delta`, `open_interest`). Cost a purchase at the ASK, state the feed timestamp, and cross-check
one contract against a quote from the user's broker. If the feed fails, ask the user for quotes. Then
restate every leg back to the user and get a yes: buy or write · contracts · strike · expiry · price.
Never infer a leg from a calculator's summary number. Sanity-check the quotes:
- the expiry is a trading day (monthlies are the third Friday, or the Thursday before a holiday);
- for one strike, a later expiry costs more. If not, a date or price is mistyped;
- contracts × 100 vs shares held: flag any excess (net short) and any shortfall (unhedged shares).
  Under 100 shares, a single-name put over-hedges. Say so and offer an index/ETF put or a trim.

## 5. Report: every structure, same table
Measure P/L from TODAY'S PRICE, never from cost basis (a calculator that starts at basis shows an
existing gain as "profit" and hides what the hedge costs). At each scenario price show hedged vs
UNHEDGED side by side, then:
- premium in $ and as % of position; the floor; the upside break-even;
- the price below which the hedge beats doing nothing, and the worst point with its loss;
- the comparison with simply trimming (unless the user must keep every share);
- **different expiries → path cases**, because a grid assumes one price at every expiry. Always
  show: (a) the early leg expires worthless, then price falls; (b) price dips, the put gains, the
  user does not sell it, price recovers and the put expires worthless;
- before expiry, value open legs with a pricing model (implied vol backed out of the quotes), and
  say that implied vol usually rises in a selloff;
- each expiry against the next earnings date and known events. Say what it covers and what it misses.

## 6. Close
Flag if no liquid options market exists yet (a days-old IPO). A put is a WASTING ASSET and a
temporary patch; sizing fixes the disease. Log the chosen structure (or the decision NOT to
hedge) via `bin/ledger append --type decision ...`, pending until the fill.
