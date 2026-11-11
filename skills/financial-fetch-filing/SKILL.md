---
name: financial-fetch-filing
description: Use when a holding or candidate has no filings on disk and you need its real SEC document (10-K, 20-F, 10-Q, S-1/424B, 8-K) from EDGAR before any analysis. Fetches the primary document, strips it to text, and extracts cited facts. Pair with financial-analyze-stock.
---
# Financial - Fetch & Extract Filing: $ARGUMENTS

Get the REAL document onto disk and extract facts from it. Documents are the foundation: never
analyze from memory or headlines. Cite file:line for EVERY number. No live price (no feed), so never
invent one; mark missing data NOT FOUND.

## Rules
- **NEVER put an email or any PII in commands/headers.** Use this exact User-Agent string:
  `fin-protek-research admin@example.com`  (data.sec.gov + www.sec.gov/Archives both need a UA;
  the generic string above passes. The user's real email must not appear anywhere.)
- US companies file **10-K** (annual) / **10-Q** (quarterly); foreign private issuers (e.g. TSM, ASML)
  file **20-F**; IPOs file **S-1 / 424B**; material events **8-K**. Pick the right form.

## Setup
- **TICKER = the first word of `$ARGUMENTS`**; anything after it says WHICH documents are wanted
  (e.g. "latest 10-K and 10-Q"). Never put the whole argument string in a path.
- Run from the workspace root (the directory holding `portfolio/` and `stocks/`).
- `BASE=stocks/<TICKER>`
- `cp -R stocks/_TEMPLATE "$BASE" 2>/dev/null; mkdir -p "$BASE/filings"`
- Index JSON and helper scripts go in the session scratchpad (`$TMP` below), never in `/tmp` or the repo.
- Download to a file, THEN run a script on that file. Never pipe `curl` into an interpreter.
  In zsh, unquoted variables are not word-split.
- Look at `ls "$BASE/filings"` first and fetch only what is missing or newer than what is on disk.

## Fetch from EDGAR
1. **CIK:** `curl -s -H "User-Agent: fin-protek-research admin@example.com" "https://www.sec.gov/files/company_tickers.json" -o "$TMP/tk.json"`, then find the entry whose `ticker` == `<TICKER>` → `cik_str`. Zero-pad to 10 digits = CIK10; integer (no leading zeros) = CIKINT.
2. **Submissions:** `curl ... "https://data.sec.gov/submissions/CIK<CIK10>.json" -o "$TMP/sub.json"`, then list `filings.recent` (form, filingDate, reportDate, accessionNumber, primaryDocument, items). Take the MOST RECENT annual report, AND every 10-Q filed after it, AND the 8-Ks since then whose items matter (1.01 agreement, 2.01 acquisition, 2.03 debt, 3.02 equity sale, 8.01 other; skip routine 2.02/5.02 unless asked). (For multi-year trend, grab the last 2-3 annuals.)
3. **Download:** `url=https://www.sec.gov/Archives/edgar/data/<CIKINT>/<accession_without_dashes>/<primaryDocument>` → `curl -s -H "User-Agent: fin-protek-research admin@example.com" --compressed "$url" -o "$BASE/filings/<TICKER>-<FORM>-<reportDate>.htm"`. **Verify it's the filing, not the block page:** `grep -c "Undeclared Automated Tool"` must be 0; if blocked, wait briefly and retry once.
   - **Foreign filers (6-K):** the primary document is usually a cover page. Fetch `.../<accession_without_dashes>/index.json`, list the `.htm` exhibits, and download the one holding the content (earnings release, financial statements, monthly revenue).
4. **Strip to text** (python: drop script/style; block tags→newline; `</td></th>`→tab; strip remaining tags; `html.unescape`) → one `.txt` beside each `.htm`, same basename. These filings are multi-MB inline-XBRL, too big to read raw. grep the text for table anchors, then read those line ranges. Delegate the tedious numeric extraction to a subagent if context is tight. Subagents may have no network, so everything they need must already be on disk.

## Extract (cite file:line each; $M unless noted)
3 fiscal years where possible: revenue, margins, operating + net income; operating cash flow vs net
income; capex; debt + maturities + coverage; cash; diluted shares + buybacks/dilution; segment AND
geographic revenue; **dividends (paid, per-share, trend, policy, payout, committed vs discretionary),
stated explicitly if none**; customer concentration; supply-chain chokepoints (foundry/fab, packaging,
sole-source, Taiwan/China) and which OTHER holdings share them; 2-3 dated/quantified risk factors and
any YoY risk-wording change.

## Write & hand off
- `$BASE/filings/extracted-financials.md`: header (source filing + filing date + extraction date),
  a years-as-columns table, then sections **Dividends**, **Exposure & supply chain**, **Citations (file:line)**.
- If `$BASE/thesis.md` predates a filing just fetched, say it is stale.
- Then continue with `/fin-protek:financial-analyze-stock <TICKER>` (thesis → red-team → risk/reward → ledger).
