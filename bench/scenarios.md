# Scenario runs

Three invented investors. Each run gives the analyst only the filings and prices that existed on an
as-of date, takes the investor's answers from a persona file, and follows the skills in order. Later
prices are held back and used only to describe what happened next.

A run passes when every "must" below is met. A missed "must" is charged to the skill that should have
caught it.

## 1. Employee with most of their money in the employer's stock

Holdings: employer stock about 60 percent, a broad index fund, cash saved for a house deposit.
Constraints: may trade only in open windows; may not buy puts or write options on the employer's stock.

- Must set concentration limits, since none exist. (`financial-onboard`)
- Must count salary and unvested stock as the same bet as the shares. (`financial-exposure-map`)
- Must not recommend an option on the employer's stock. (`financial-hedge-design`)
- Must give a staged trim plan that fits the trading windows and states what future vests do. (`financial-conviction-test`)
- Must leave the house-deposit cash in cash. (`financial-find-ideas`)

## 2. Employee who believes a second sector makes them diversified

Holdings: employer stock about 60 percent, two oil majors about 30 percent, cash.
Constraints: same employer rules. The investor sells after drops and asks whether to add to oil.

- Must test the "opposites" belief with the price files and the filings, and show the numbers. (`financial-exposure-map`)
- Must count the two oil majors as one bet. (`financial-exposure-map`)
- Must answer the add question through the add gate, not by opinion. (`financial-find-ideas`, `financial-position-check`)
- Must name the habit of selling after drops and set a rule for it in advance. (`financial-conviction-test`)

## 3. Investor concentrated in one sector they work in

Holdings: four healthcare names, one far above cost with a tax objection to selling, one below cost
kept "to get back to even". The investor asks whether to buy more of a name that fell.

- Must challenge "this sector cannot fall" with the price history. (`financial-exposure-map`)
- Must name anchoring on cost basis for the holding kept to get back to even. (`financial-conviction-test`)
- Must refuse a continue-or-add verdict where no thesis is written, then write one from the filings. (`financial-analyze-stock`)
- Must treat the tax objection as a stated constraint and offer a hedge or a staged trim. (`financial-conviction-test`, `financial-hedge-design`)
- Must run the adversarial board before any buy. (`financial-red-team-board`)

## Every scenario

- Every number cites a file and line.
- Every decision is in the ledger with a strategy id, a horizon, early-disproof facts, and status pending.
- No option premium is estimated when no chain is available.
- A decided strategy gets a card.
