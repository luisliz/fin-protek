# PORTFOLIO - current holdings (UPDATE THE MOMENT YOU TRADE)

Written by `/fin-protek:financial-onboard` (it records; it tests nothing). Every answer below is in
one of three states: the user's answer; "not asked yet" (listed under Questions owed); or
"declined on <date>" (asked and refused). No default fills a gap.

## Positions (market value, YYYY-MM-DD)

| Ticker | Shares | Price | Mkt value | % (mkt) | Cost basis / share | Note |
|---|--:|--:|--:|--:|--:|---|
|  |  |  |  |  |  |  |
| Cash |  |  |  |  |  |  |
| **Total** |  |  |  | 100% |  |  |

Write the date the prices were taken in the heading above and their source (user-supplied, or the
price file). Value and % come from a script over this table, never from mental arithmetic.

## Goals

At least one row. Kinds: long-run pot; sum by a date (date "standing" for a reserve with no date);
income; debt payoff. Each holding and each cash amount is assigned to exactly one goal, by the
user; money the user gives no other job is the long-run pot. Money for a date within 5 years gets
its own row and its own cash, never blended in.

| Goal | Kind | Amount, or income needed per year from this account | Date | Tolerance, in the user's words | Tolerance as a number | Tolerance state | Holdings or cash assigned |
|---|---|--:|---|---|---|---|---|
| Long-run pot | long-run pot |  | none | "<user's words>" | L: __% ($__) | not asked yet |  |

Tolerance by kind: long-run pot, the loss L the user could bear; sum by a date, the loss they could
bear on that amount (0 is valid); income, the cut they could bear, which sets the floor (income
needed minus the cut; "none" is valid and means floor = need); debt payoff, the balance, rate and
the date the terms change. Tolerance state: confirmed (on <date>), unconfirmed (given with doubt;
shown beside its replayed fall in dollars until the user confirms or changes it), not asked yet,
declined (on <date>).

## Outside this account

Every row may be "none". "Shares a driver with" names what the item has in common with the
holdings: the employer's stock, an industry or cycle, interest rates, a property market.

| Item | Value, balance or income per year | Shares a driver with | Dates and terms |
|---|--:|---|---|
| MAIN INCOME of the household (employer and ticker, business, self-employment, rent) |  |  | stable or variable; what would stop it |
| Other household income (partner, pension in payment, social security) |  |  |  |
| Unvested or deferred stock (money that will arrive, not held) |  |  | arrival dates; lost on leaving? |
| Employer plan (discount purchase, match, grant, deferred bonus) |  |  | discount; lower of start or end; contribution; purchase dates; holding period |
| Pension tied to the employer |  |  |  |
| Property |  |  |  |
| Mortgage or other debt |  |  | balance; rate (fixed or variable); reset date; prepayment terms |
| Other accounts |  |  |  |

- L_main, the loss on THIS ACCOUNT's value (never the outside items) the user could bear in a year
  the main income stopped: "<user's words>", __% ($__); state: not asked yet

## Trading rules

Rules from an employer and rules the user set (for example "no options"). Every proposed
instrument is checked against the scope, index and sector funds included.

- Open windows:
- Pre-clearance (lead time):
- Minimum holding period (does a vest or plan purchase start the clock?):

| Banned (options, hedging, short sales, purchases, other) | Scope (named tickers, or a class such as "every financial company") | Source (employer, user) |
|---|---|---|
|  |  |  |

## Concentration limits

`/fin-protek:financial-exposure-map` proposes each limit from `bin/optcalc book` and writes its
working to `portfolio/exposure-map.md`; this table records only the value and its state. State:
"set by the user on <date>", "proposed on <date>", "accepted by the user on <date>", or "declined
on <date>". A proposed limit may block an add; it never places or schedules a sale.

| Limit (goal, holding, cluster, income-linked bet, minimum cash, minimum independent drivers) | Value | State |
|---|--:|---|
|  |  |  |

## Options and standing orders

| Strategy id | Instrument | Contracts | Cost | Order (type, price, duration) | Status (planned, placed, filled) | Fills at about | Sell-by date |
|---|---|--:|--:|---|---|--:|---|
|  |  |  |  |  |  |  |  |

## Deliberate bets

Concentrations you hold on purpose, each with one line of reasoning.

## Notes

- Tax on realized gains blocks selling, per holding (ticker: yes | no; account taxable | retirement;
  rate and holding period when the user knows them):
- Cash set aside (amount, purpose, date or "standing"). No skill may invest this cash:
- Corrections: a value the user changed (old, new, date the user gave it):
- Carried over: lines from an older layout with no field above, kept word for word:

## Questions owed

One line per question not asked yet, or asked and still unconfirmed, with the skill that needs it
(for example "L_main: not asked yet; needed by the exposure map").

-
