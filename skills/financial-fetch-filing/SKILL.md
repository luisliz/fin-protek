---
name: financial-fetch-filing
description: Puts a company's or fund's real SEC documents on disk from EDGAR (10-K, 10-Q, 20-F, 40-F, 6-K, S-1/424B, 8-K, NPORT-P), keeps a manifest so each is fetched once, and extracts cited facts. Use when the user says "pull the 10-K", "get the filings", "fetch the latest quarter", "when do they report", or a skill finds `stocks/<TICKER>/filings/` empty, unlisted or out of date. Not for analysis or opinions (financial-analyze-stock) or issuers that do not file with the SEC.
---
# Financial - Fetch & Extract Filing: $ARGUMENTS

Its one question: are the real documents on disk? Never analyze from memory or headlines. Cite
file:line for EVERY number; mark missing data NOT FOUND. No live price feed: never invent one.

## Rules
- **No email or PII in any command or header.** Every sec.gov request uses
  `H='User-Agent: fin-protek-research admin@example.com'`.
- Forms: US companies file 10-K / 10-Q; foreign private issuers 20-F (annual) and 6-K (interim,
  events); Canadian MJDS issuers 40-F; IPOs S-1 / 424B; material events 8-K; funds NPORT-P.
- Download to a file, THEN run a script on it. Never pipe `curl` into an interpreter.
- No network → say so, backfill the manifest (below), list what is on disk, and ask the user to
  save each missing document to `filings/`.

## Setup
- TICKER = the first word of `$ARGUMENTS`; the rest says WHICH documents. From the workspace root:
  `BASE=stocks/<TICKER>`; `$TMP` = the session scratchpad, never `/tmp` or the repo.
- No `stocks/_TEMPLATE/` → run `/fin-protek:financial-onboard` first. Then `mkdir -p
  "$BASE/filings" "$BASE/reading"`; a company only: `cp -n stocks/_TEMPLATE/thesis.md "$BASE/"`.
- **Manifest first**: `$BASE/filings/INDEX.md`, one row per document: form | period end | filed |
  accession | file | bytes | fetched | note ("statements", "no statements", "cover page"). No
  file → create it with that header, then **backfill**: one row per file already in `filings/`,
  form, period and accession read from its cover page, bytes from `ls -l`. No network needed.
  Fetch only what the manifest lacks; an annual once a year.

## Fetch from EDGAR
1. **CIK:** `curl -s -H "$H" "https://www.sec.gov/files/company_tickers.json" -o "$TMP/tk.json"`;
   `ticker` == TICKER → `cik_str`. CIK10 = zero-padded to 10 digits; CIKINT = no leading zeros.
   Not found → `company_tickers_mf.json` (funds; `symbol` → `cik` and `seriesId`). In neither →
   not an SEC filer or a different ticker: ask the user and stop.
2. **List:** `curl -s -H "$H" "https://data.sec.gov/submissions/CIK<CIK10>.json" -o "$TMP/sub.json"`;
   read `filings.recent` (form, filingDate, reportDate, accessionNumber, primaryDocument, items).
   Wanted: the two newest annuals that hold statements; every 10-Q or 6-K after the latest annual;
   8-Ks since then with items 1.01, 2.01, 2.03, 3.02 or 8.01; and the newest 8-K or 6-K that
   announces the next results date (record it under **Dated events**, cited).
3. **Download** what the manifest lacks: `url=https://www.sec.gov/Archives/edgar/data/<CIKINT>/<accession_no_dashes>/<primaryDocument>`;
   `curl -s -H "$H" --compressed "$url" -o "$BASE/filings/<TICKER>-<FORM>-<reportDate>.htm"`,
   with `/` in FORM replaced by `_` (10-K/A → 10-K_A), and `-<accession>` appended for 8-K and 6-K.
   - Block page: `grep -c "Undeclared Automated Tool"` must be 0. Blocked → wait, retry once.
   - **Statements check, every annual (10-K, 20-F, 40-F, and any /A)**: a balance sheet, income
     statement and cash-flow statement in the text. A file under about 20 KB → "cover page". An
     amendment holding only part of the report (a Part III 10-K/A), or a shell that incorporates
     by reference and names an exhibit (Exhibit 15 for a 20-F, Exhibits 99.1-99.3 for a 40-F) →
     "no statements". Then fetch what holds them: the original annual the amendment amends, or
     the exhibit from `curl -s -H "$H" ".../<accession_no_dashes>/index.json" -o "$TMP/idx.json"`.
     Record both rows; the note names the file that holds the statements.
   - Nothing on EDGAR holds them → "<form> <date>: no statements, content NOT FOUND". A cover
     page or a "no statements" row never counts as the latest annual and is never extracted.
4. **Facts file**, once, refreshed only when the manifest gains an annual or interim row:
   `curl -s -H "$H" --compressed "https://data.sec.gov/api/xbrl/companyfacts/CIK<CIK10>.json" -o "$BASE/filings/companyfacts.json"`
5. **Strip to text** with a `python3 -I` script in `$TMP`: drop script/style; block tags → newline;
   `</td></th>` → tab; strip remaining tags; `html.unescape`. One `.txt` beside each `.htm`.

## Funds (ETF, mutual fund): no 10-K exists
- Documents: the prospectus (485BPOS or 497K) and the full holdings list. NPORT-P: the trust
  files one per series; take the newest whose `seriesId` matches. Fetch its raw `primary_doc.xml`
  (drop any `xsl.../` prefix from primaryDocument). Parse it with a `python3 -I` script using
  `xml.etree.ElementTree`: each element whose tag ends in `invstOrSec` → name, CUSIP (or the ISIN
  `value` under identifiers), `pctVal`. Write all rows to `filings/holdings-<date>.csv`, never a
  top 10. The issuer's holdings file saved by the user serves the same purpose.
- Prospectus or holdings list not on disk → the fund is **awaiting documents**: say which is
  missing, test it by price history only (`curl -sL -A "Mozilla/5.0" "https://query1.finance.yahoo.com/v8/finance/chart/<TICKER>?period1=0&period2=9999999999&interval=1d" -o "$TMP/px-<TICKER>.json"`;
  state its first date), and list it under Questions owed. It is not "not assessed".
- **Fund note** (`$BASE/thesis.md`): what it tracks, expense ratio, holdings list date and
  source, each cited, or "awaiting documents: <what>". The exposure map does the look-through.

## Extract (cite each figure; $M unless noted)
- `$BASE/filings/extracted-financials.md` is the cache. Its header names the source filings by
  accession and filed date. They match the manifest's newest "statements" rows → reuse it, stop.
  Otherwise extract only the new filing and append.
- Multi-year table: `bin/optcalc facts --facts "$BASE/filings/companyfacts.json" --ticker <TICKER>`.
  Never rebuild it by reading the annual. A row prints NOT FOUND → take it from the filing text,
  cite file:line, and say the tag was missing.
- **Dividends**: per share, dividends paid, policy; "none" stated explicitly. Cover for each of 3
  years by a `python3 -I` script: free cash flow / dividends paid; banks and insurers: net income
  to common / common dividends, plus payout and buybacks against CET1 minus its requirement. List
  one-off items the cash-flow notes disclose in each year, cited. Cover is a weak predictor of a cut.
- From the filing text only what the facts table cannot give: segment and geographic revenue;
  customer concentration; supply-chain chokepoints and which OTHER holdings share them; debt
  maturities and covenants; 2-3 dated, quantified risk factors and wording changed since the prior
  annual (prior annual not on disk and not fetchable → NOT FOUND).
- Banks add: CET1, LCR, net charge-off rate, allowance, held-to-maturity unrealized loss, deposit
  mix. REITs add: FFO and AFFO per share, payout of AFFO, occupancy, equity issued.
- Every other ratio by a `python3 -I` script, never by the model. Show the command and its inputs.

## Write and tell the user
- `extracted-financials.md`: the header, the facts table, then **Dividends**, **Exposure & supply
  chain**, **Risk changes**, **Dated events**, **Citations (file:line)**.
- Tell the user: each form fetched with its date; each cover page, "no statements" row and NOT
  FOUND; the file that holds the statements; any fund awaiting documents; and whether `thesis.md`
  predates a filing just fetched (stale).

## Next
- Company extraction written → `/fin-protek:financial-analyze-stock <TICKER>`.
- Fund note written or awaiting documents → `/fin-protek:financial-exposure-map`.
