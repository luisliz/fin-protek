(* optcalc.ml: option arithmetic for bought calls and puts.
   Arithmetic is owned by THIS program, not by any LLM prompt.
   - screen : list affordable, liquid calls and puts from a Cboe delayed chain and
              compare each break-even with the stock's own daily price history.
   - value  : back implied vol out of one contract's mid quote (Black-Scholes,
              European, no dividends), then reprice it at a stock level on a date.
   - drawdown : the largest peak-to-trough falls in one stock's adjusted closes, with
              trading days down and days back to the old peak.
   - corr   : correlation of two stocks' daily returns on their common dates, whole
              overlap and per calendar year, plus what each did during the other's
              largest falls.
   - facts  : a company's own XBRL figures from the SEC company-facts JSON: three or more
              fiscal years and the newest interim period for a fixed list of concepts, each
              cell cited to its tag, accession, form and filed date.
   - book   : replay the holdings at today's mix over their common dates, with cash a fixed
              amount outside the replay: the largest falls as a percent of the invested part
              and of the whole portfolio, each holding's dollar contribution, pairwise
              evidence for one-bet links (correlation, co-falling) with suggested links, and
              with a tolerance, the pro-rata size at which the worst fall stays inside it.
   - income : yearly dividend income from each holding's latest declared dividend per
              share in its company-facts file, plus user-supplied income, against a need
              and a floor, with free-cash-flow cover of dividends paid for three years.
   Reads files on disk only; no network. Every printed number traces to an input
   file or a flag.
   stdlib + unix only; compiles to a single dependency-free native binary. *)

let usage =
  "usage: optcalc screen --chain FILE --history FILE --ticker T --max-ask X\n\
  \                      [--min-oi 100] [--max-spread 0.25] [--min-days 30] [--max-days 240]\n\
  \       optcalc value --chain FILE --ticker T --expiry YYYY-MM-DD --strike K --kind P|C\n\
  \                     --at STOCKPRICE --on YYYY-MM-DD [--rate 0.04]\n\
  \       optcalc drawdown --history FILE --ticker T\n\
  \       optcalc corr --history FILE_A --ticker A --history FILE_B --ticker B\n\
  \       optcalc facts --facts FILE --ticker T [--years 3]\n\
  \       optcalc book --position T=VALUE:FILE [--position ...] [--cash 0]\n\
  \                    [--tolerance L] [--corr-years 10]\n\
  \       optcalc income --holding T=SHARES:FACTSFILE [--holding ...] [--other NAME=AMOUNT ...]\n\
  \                      --need N [--floor F]"

let bad_usage () = prerr_endline usage; exit 2
let die msg = prerr_endline ("optcalc: " ^ msg); exit 1
(* a bad argument with a reason: exit 2, as bad_usage *)
let bad_arg msg = prerr_endline ("optcalc: " ^ msg); exit 2

(* ---- facts: the concept table ----
   One row per concept. Per taxonomy, a concept has parts; a part has ordered fallback
   recipes; a recipe is a list of tags summed for one period, and every tag in it must
   have a fact for that period. For each period the first recipe with data wins, except
   in a part marked [largest]: there every recipe with data is read and the largest sum
   wins (the first in order on a tie). Revenue is such a part: a filer can tag only part
   of its revenue (contracts with customers) next to a total-revenue tag, and the part
   is never larger than the total. A part that is not required may be absent; its cell
   then says so and nothing is added.
   Free cash flow is not tagged: it is computed from the operating cash flow and capital
   expenditure rows. concept_table below is the one list of tags; change tags only there.
   Deliberately absent: property acquisitions (a REIT's PaymentsToAcquireRealEstate is
   growth spending, not upkeep) and partial debt tags (a REIT's NotesPayable alone is not
   its total debt). Missing beats wrong. *)
type period_kind = Flow | Instant
type unit_kind = Money | Per_share | Shares
type part = { part : string; recipes : string list list; required : bool; largest : bool }
type concept = { label : string; pk : period_kind; uk : unit_kind; gaap : part list; ifrs : part list }
type entry = Tagged of concept | Free_cash_flow

let one tags = [ { part = ""; recipes = List.map (fun t -> [t]) tags; required = true; largest = false } ]
let largest_of tags = List.map (fun p -> { p with largest = true }) (one tags)

let ocf_label = "Operating cash flow" and capex_label = "Capital expenditure"

let concept_table = [
  Tagged { label = "Revenue"; pk = Flow; uk = Money;
           gaap = largest_of ["RevenueFromContractWithCustomerExcludingAssessedTax"; "Revenues";
                              "SalesRevenueNet"; "RevenuesNetOfInterestExpense"];
           ifrs = largest_of ["Revenue"] };
  Tagged { label = "Operating income"; pk = Flow; uk = Money;
           gaap = one ["OperatingIncomeLoss"];
           ifrs = one ["ProfitLossFromOperatingActivities"] };
  Tagged { label = "Net income"; pk = Flow; uk = Money;
           gaap = one ["NetIncomeLoss"; "ProfitLoss"];
           ifrs = one ["ProfitLossAttributableToOwnersOfParent"; "ProfitLoss"] };
  Tagged { label = ocf_label; pk = Flow; uk = Money;
           gaap = one ["NetCashProvidedByUsedInOperatingActivities";
                       "NetCashProvidedByUsedInOperatingActivitiesContinuingOperations"];
           ifrs = one ["CashFlowsFromUsedInOperatingActivities"] };
  Tagged { label = capex_label; pk = Flow; uk = Money;
           gaap = one ["PaymentsToAcquirePropertyPlantAndEquipment"; "PaymentsToAcquireProductiveAssets";
                       "PaymentsToAcquireOtherProductiveAssets"];
           ifrs = one ["PurchaseOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities";
                       "PurchaseOfPropertyPlantAndEquipment"] };
  Free_cash_flow;
  Tagged { label = "Cash and equivalents"; pk = Instant; uk = Money;
           gaap = one ["CashAndCashEquivalentsAtCarryingValue";
                       "CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents"];
           ifrs = one ["CashAndCashEquivalents"] };
  Tagged { label = "Total debt"; pk = Instant; uk = Money;
           gaap = [
             { part = "long-term debt incl. current portion"; required = true; largest = false;
               recipes = [ ["LongTermDebt"];
                           ["LongTermDebtAndCapitalLeaseObligationsIncludingCurrentMaturities"];
                           ["LongTermDebtNoncurrent"; "LongTermDebtCurrent"];
                           ["LongTermDebtAndCapitalLeaseObligations";
                            "LongTermDebtAndCapitalLeaseObligationsCurrent"] ] };
             { part = "short-term borrowings"; required = false; largest = false;
               recipes = [ ["ShortTermBorrowings"];
                           ["CommercialPaper"; "OtherShortTermBorrowings"];
                           ["CommercialPaper"]; ["OtherShortTermBorrowings"] ] } ];
           ifrs = [ { part = "borrowings, current and non-current"; required = true; largest = false;
                      recipes = [ ["Borrowings"] ] } ] };
  Tagged { label = "Diluted shares (weighted average)"; pk = Flow; uk = Shares;
           gaap = one ["WeightedAverageNumberOfDilutedSharesOutstanding"];
           ifrs = one ["AdjustedWeightedAverageShares"] };
  Tagged { label = "Dividends declared per share"; pk = Flow; uk = Per_share;
           gaap = one ["CommonStockDividendsPerShareDeclared"; "CommonStockDividendsPerShareCashPaid"];
           ifrs = one ["DividendsRecognisedAsDistributionsToOwnersPerShare";
                       "DividendsPaidOrdinarySharesPerShare"] };
  Tagged { label = "Dividends paid"; pk = Flow; uk = Money;
           gaap = one ["PaymentsOfDividendsCommonStock"; "PaymentsOfDividends"];
           ifrs = one ["DividendsPaidClassifiedAsFinancingActivities"; "DividendsPaid"] };
]

(* a fallback tag whose meaning differs from the row label carries this note into its cell *)
let tag_notes = [
  ("RevenuesNetOfInterestExpense", "bank net revenue after interest expense");
  ("ProfitLoss", "includes non-controlling interests");
  ("CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents", "includes restricted cash");
  ("CommonStockDividendsPerShareCashPaid", "paid, not declared");
  ("DividendsPaidOrdinarySharesPerShare", "paid, not declared");
  ("PaymentsOfDividends", "may include preferred dividends") ]

(* ---- minimal JSON reader ---- *)
type json =
  | Null
  | Bool of bool
  | Num of float * bool          (* value, written without '.' or exponent *)
  | Str of string
  | Arr of json list
  | Obj of (string * json) list

exception Bad_json of int * string

let parse_json s =
  let n = String.length s and pos = ref 0 in
  let fail m = raise (Bad_json (!pos, m)) in
  let peek () = if !pos < n then s.[!pos] else fail "unexpected end" in
  let rec ws () =
    if !pos < n then match s.[!pos] with
      | ' ' | '\t' | '\n' | '\r' -> incr pos; ws ()
      | _ -> () in
  let expect c =
    if !pos < n && s.[!pos] = c then incr pos
    else fail (Printf.sprintf "expected '%c'" c) in
  let lit w v =
    let l = String.length w in
    if !pos + l <= n && String.sub s !pos l = w then (pos := !pos + l; v)
    else fail "bad literal" in
  let hex4 () =
    if !pos + 4 > n then fail "short \\u escape";
    match int_of_string_opt ("0x" ^ String.sub s !pos 4) with
    | Some v -> pos := !pos + 4; v
    | None -> fail "bad \\u escape" in
  let add_uchar b u =
    Buffer.add_utf_8_uchar b (if Uchar.is_valid u then Uchar.of_int u else Uchar.rep) in
  let str () =
    expect '"';
    let b = Buffer.create 16 in
    let rec go () =
      let c = peek () in
      incr pos;
      match c with
      | '"' -> Buffer.contents b
      | '\\' ->
          let e = peek () in
          incr pos;
          (match e with
           | '"' | '\\' | '/' -> Buffer.add_char b e
           | 'b' -> Buffer.add_char b '\b'
           | 'f' -> Buffer.add_char b '\012'
           | 'n' -> Buffer.add_char b '\n'
           | 'r' -> Buffer.add_char b '\r'
           | 't' -> Buffer.add_char b '\t'
           | 'u' ->
               let u = hex4 () in
               (* join a UTF-16 surrogate pair *)
               if u >= 0xD800 && u < 0xDC00 && !pos + 1 < n
                  && s.[!pos] = '\\' && s.[!pos + 1] = 'u' then begin
                 pos := !pos + 2;
                 let lo = hex4 () in
                 if lo >= 0xDC00 && lo < 0xE000 then
                   add_uchar b (0x10000 + ((u - 0xD800) lsl 10) + (lo - 0xDC00))
                 else (add_uchar b u; add_uchar b lo)
               end else add_uchar b u
           | _ -> fail "bad escape");
          go ()
      | c -> Buffer.add_char b c; go () in
    go () in
  let num () =
    let st = !pos and is_int = ref true in
    let rec scan () =
      if !pos < n then match s.[!pos] with
        | '0' .. '9' | '-' | '+' -> incr pos; scan ()
        | '.' | 'e' | 'E' -> is_int := false; incr pos; scan ()
        | _ -> () in
    scan ();
    match float_of_string_opt (String.sub s st (!pos - st)) with
    | Some f -> Num (f, !is_int)
    | None -> fail "bad number" in
  let rec value () =
    ws ();
    match peek () with
    | '{' ->
        incr pos; ws ();
        if peek () = '}' then (incr pos; Obj [])
        else
          let rec members acc =
            ws ();
            let k = str () in
            ws (); expect ':';
            let v = value () in
            ws ();
            if peek () = ',' then (incr pos; members ((k, v) :: acc))
            else (expect '}'; Obj (List.rev ((k, v) :: acc))) in
          members []
    | '[' ->
        incr pos; ws ();
        if peek () = ']' then (incr pos; Arr [])
        else
          let rec items acc =
            let v = value () in
            ws ();
            if peek () = ',' then (incr pos; items (v :: acc))
            else (expect ']'; Arr (List.rev (v :: acc))) in
          items []
    | '"' -> Str (str ())
    | 't' -> lit "true" (Bool true)
    | 'f' -> lit "false" (Bool false)
    | 'n' -> lit "null" Null
    (* Python's json module also writes these *)
    | 'N' -> lit "NaN" (Num (Float.nan, false))
    | 'I' -> lit "Infinity" (Num (Float.infinity, false))
    | '-' when !pos + 1 < n && s.[!pos + 1] = 'I' ->
        lit "-Infinity" (Num (Float.neg_infinity, false))
    | _ -> num () in
  let v = value () in
  ws ();
  if !pos <> n then fail "trailing data";
  v

let member k = function
  | Obj l -> (match List.assoc_opt k l with Some v -> v | None -> Null)
  | _ -> Null

let first = function Arr (v :: _) -> v | _ -> Null

(* a missing, null or zero number reads as 0.0, as Python's `x or 0.0` *)
let num_or0 = function Num (f, _) -> f | _ -> 0.0

let load_json path =
  if not (Sys.file_exists path) then die ("no such file: " ^ path);
  let s = In_channel.with_open_bin path In_channel.input_all in
  try parse_json s
  with Bad_json (at, m) -> die (Printf.sprintf "%s: bad JSON at byte %d: %s" path at m)

(* ---- number formatting ---- *)

(* shortest round-trip text, laid out as Python's repr: 47.645, 470.0, 1e-05 *)
let py_float x =
  if Float.is_nan x then "nan"
  else if Float.is_integer x && Float.abs x < 1e16 then Printf.sprintf "%.1f" x
  else
    let rec shortest p =
      let e = Printf.sprintf "%.*e" (p - 1) x in
      if p >= 17 || float_of_string e = x then e else shortest (p + 1) in
    let e = shortest 1 in
    let i = String.index e 'e' in
    let mant = String.sub e 0 i and ex = int_of_string (String.sub e (i + 1) (String.length e - i - 1)) in
    let neg = mant.[0] = '-' in
    let digits = String.concat "" (String.split_on_char '.' (if neg then String.sub mant 1 (String.length mant - 1) else mant)) in
    let nd = String.length digits in
    let body =
      if ex < -4 || ex >= 16 then
        let m = if nd = 1 then digits else String.sub digits 0 1 ^ "." ^ String.sub digits 1 (nd - 1) in
        Printf.sprintf "%se%s%02d" m (if ex < 0 then "-" else "+") (abs ex)
      else if ex < 0 then "0." ^ String.make (- ex - 1) '0' ^ digits
      else if nd <= ex + 1 then digits ^ String.make (ex + 1 - nd) '0' ^ ".0"
      else String.sub digits 0 (ex + 1) ^ "." ^ String.sub digits (ex + 1) (nd - ex - 1) in
    (if neg then "-" else "") ^ body

(* a JSON number as Python prints it: integers bare, floats by repr *)
let py_num = function
  | Num (f, true) -> Printf.sprintf "%.0f" f
  | Num (f, false) -> py_float f
  | Str s -> s
  | _ -> "None"

(* Python's {:.Nf%}: multiply by 100, then fixed *)
let pct digits x = Printf.sprintf "%.*f%%" digits (x *. 100.0)
let pct_signed digits x = Printf.sprintf "%+.*f%%" digits (x *. 100.0)

(* Python's round(): half to even *)
let round_half_even x =
  let f = Float.floor x in
  let d = x -. f in
  if d > 0.5 then f +. 1.0
  else if d < 0.5 then f
  else if Float.rem f 2.0 = 0.0 then f else f +. 1.0

(* ---- dates as days since 1970-01-01 ---- *)
let days_from_civil y m d =
  let y = if m <= 2 then y - 1 else y in
  let era = (if y >= 0 then y else y - 399) / 400 in
  let yoe = y - era * 400 in
  let doy = (153 * ((m + 9) mod 12) + 2) / 5 + d - 1 in
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy in
  era * 146097 + doe - 719468

let day_of_epoch secs =
  let tm = Unix.gmtime secs in
  days_from_civil (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

let iso_of_day z =
  let tm = Unix.gmtime (float_of_int z *. 86400.0) in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

(* a real calendar date, or None; rejects 2026-02-30 by round trip *)
let valid_day y m d =
  if m < 1 || m > 12 || d < 1 || d > 31 then None
  else
    let z = days_from_civil y m d in
    if iso_of_day z = Printf.sprintf "%04d-%02d-%02d" y m d then Some z else None

(* "YYYY-MM-DD..." -> day; only the first 10 characters are read *)
let parse_iso s =
  if String.length s < 10 then None
  else try Scanf.sscanf (String.sub s 0 10) "%4d-%2d-%2d%!" valid_day
       with _ -> None

(* ---- chain helpers ---- *)

(* Cboe symbol TICKER + YYMMDD + C|P + strike*1000 in 8 digits -> (expiry day, strike) *)
let parse_symbol ticker kind sym =
  let tl = String.length ticker in
  let digits s = String.for_all (fun c -> c >= '0' && c <= '9') s in
  if String.length sym <> tl + 15 || String.sub sym 0 tl <> ticker
     || sym.[tl + 6] <> kind then None
  else
    let ymd = String.sub sym tl 6 and k = String.sub sym (tl + 7) 8 in
    if not (digits ymd && digits k) then None
    else
      let two i = int_of_string (String.sub ymd i 2) in
      let yy = two 0 in
      let year = if yy < 69 then 2000 + yy else 1900 + yy in
      match valid_day year (two 2) (two 4) with
      | Some exp -> Some (exp, float_of_int (int_of_string k) /. 1000.0)
      | None -> None

type chain = { stamp : string; today : int; spot : float; spot_text : string; options : json list }

let load_chain path =
  let raw = load_json path in
  let data = member "data" raw in
  let stamp = match member "timestamp" raw, member "last_trade_time" data with
    | Str s, _ | _, Str s -> s
    | _ -> die (path ^ ": no feed timestamp") in
  let today = match parse_iso stamp with
    | Some d -> d
    | None -> die (path ^ ": unreadable feed timestamp " ^ stamp) in
  let spot_j = member "current_price" data in
  let spot = match spot_j with
    | Num (f, _) when f > 0.0 -> f
    | _ -> die (path ^ ": no current_price") in
  let options = match member "options" data with
    | Arr l -> l
    | _ -> die (path ^ ": no options array") in
  { stamp; today; spot; spot_text = py_num spot_j; options }

(* ---- screen ---- *)
let delta_lo = 0.10 and delta_hi = 0.60

type row = {
  exp : int; days : int; strike : float; bid : float; ask : float; spread : float;
  oi : float; iv : float; delta : float; breakeven : float; need : float;
  p_be : float; p_double : float; payoff : float }

(* (days, adjusted closes) with a null or zero close dropped *)
let dated_history path =
  let res = first (member "result" (member "chart" (load_json path))) in
  let ts = match member "timestamp" res with Arr l -> l | _ -> [] in
  let closes = match member "adjclose" (first (member "adjclose" (member "indicators" res))) with
    | Arr l -> l | _ -> [] in
  if List.length ts <> List.length closes then die (path ^ ": timestamp and adjclose lengths differ");
  let pairs = List.filter_map (fun (t, c) ->
    match t, c with
    | Num (t, _), Num (c, _) when c <> 0.0 -> Some (t, c)
    | _ -> None) (List.combine ts closes) in
  if pairs = [] then die (path ^ ": no closes");
  let days = Array.of_list (List.map (fun (t, _) -> day_of_epoch t) pairs) in
  (* a request with the wrong parameters returns weekly or monthly bars; refuse them *)
  let m = Array.length days - 1 in
  if m >= 1 then begin
    let gaps = Array.init m (fun i -> days.(i + 1) - days.(i)) in
    Array.sort compare gaps;
    let median = if m mod 2 = 1 then float_of_int gaps.(m / 2)
                 else 0.5 *. float_of_int (gaps.(m / 2 - 1) + gaps.(m / 2)) in
    if median > 4.0 then
      die (Printf.sprintf "%s is not a daily price history (median gap %g days); fetch it with \
                           period1=0&period2=9999999999&interval=1d" path median)
  end;
  (days, Array.of_list (List.map snd pairs))

(* adjusted closes plus first and last dates *)
let history path =
  let (days, closes) = dated_history path in
  (closes, days.(0), days.(Array.length days - 1))

let window_returns closes n =
  Array.init (Array.length closes - n) (fun i -> closes.(i + n) /. closes.(i) -. 1.0)

(* left-to-right sum, as Python 3.9's sum() *)
let sum f a = Array.fold_left (fun acc x -> acc +. f x) 0.0 a

let screen chain ticker kind ~max_ask ~min_oi ~max_spread ~min_days ~max_days closes =
  let sign = if kind = 'C' then 1.0 else -1.0 in
  let spot = chain.spot in
  let cache = Hashtbl.create 16 in
  let rows = List.filter_map (fun o ->
    match member "option" o with
    | Str sym -> (
        match parse_symbol ticker kind sym with
        | None -> None
        | Some (exp, strike) ->
            let days = exp - chain.today in
            let bid = num_or0 (member "bid" o) and ask = num_or0 (member "ask" o) in
            if not (min_days <= days && days <= max_days) || bid <= 0.0
               || not (0.0 < ask && ask <= max_ask) then None
            else
              let mid = 0.5 *. (bid +. ask) in
              let oi = num_or0 (member "open_interest" o) in
              let delta = Float.abs (num_or0 (member "delta" o)) in
              let spread = (ask -. bid) /. mid in
              if oi < min_oi || spread > max_spread
                 || not (delta_lo <= delta && delta <= delta_hi) then None
              else begin
                let n = int_of_float (round_half_even (float_of_int (days * 252) /. 365.0)) in
                if n >= Array.length closes then
                  die (Printf.sprintf "history has %d closes, too short for a %d-day window"
                         (Array.length closes) n);
                let rets = match Hashtbl.find_opt cache n with
                  | Some r -> r
                  | None -> let r = window_returns closes n in Hashtbl.add cache n r; r in
                let len = float_of_int (Array.length rets) in
                let breakeven = strike +. sign *. ask in
                let double = strike +. sign *. 2.0 *. ask in
                let need = breakeven /. spot -. 1.0 in
                let need_double = double /. spot -. 1.0 in
                let share t = sum (fun r -> if sign *. r >= sign *. t then 1.0 else 0.0) rets /. len in
                let payoff =
                  sum (fun r -> Float.max (sign *. (spot *. (1.0 +. r) -. strike)) 0.0) rets
                  /. len /. ask in
                Some { exp; days; strike; bid; ask; spread; oi;
                       iv = num_or0 (member "iv" o); delta; breakeven; need;
                       p_be = share need; p_double = share need_double; payoff }
              end)
    | _ -> None) chain.options in
  List.stable_sort (fun a b -> compare (a.exp, a.strike) (b.exp, b.strike)) rows

let table rows =
  let head = [
    "| expiry | days | strike | bid | ask | spread | OI | iv | delta | breakeven | need% | hist_BE | hist_2x | hist_payoff |";
    "|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|" ] in
  let line r =
    Printf.sprintf "| %s | %d | %g | %.2f | %.2f | %s | %.0f | %.3f | %.2f | %.2f | %s | %s | %s | %.2f |"
      (iso_of_day r.exp) r.days r.strike r.bid r.ask (pct 0 r.spread) r.oi r.iv r.delta
      r.breakeven (pct_signed 1 r.need) (pct 0 r.p_be) (pct 0 r.p_double) r.payoff in
  head @ (if rows = [] then ["| none passed the filters | | | | | | | | | | | | | |"]
          else List.map line rows)

let screen_cmd ~chain_path ~history_path ~ticker ~max_ask ~min_oi ~max_spread ~min_days ~max_days =
  let chain = load_chain chain_path in
  let (closes, d0, d1) = history history_path in
  let run kind = screen chain ticker kind ~max_ask ~min_oi ~max_spread ~min_days ~max_days closes in
  let calls = run 'C' and puts = run 'P' in
  let oi_text = if Float.is_integer min_oi then Printf.sprintf "%.0f" min_oi else py_float min_oi in
  let out = [
    Printf.sprintf "# %s bought-option candidates" ticker;
    "";
    Printf.sprintf "- Chain: Cboe delayed feed, %s UTC. Spot %s." chain.stamp chain.spot_text;
    Printf.sprintf "- Price history: Yahoo daily adjusted closes, %s to %s (%d days)."
      (iso_of_day d0) (iso_of_day d1) (Array.length closes);
    Printf.sprintf "- Filters: ask <= %.2f (one contract <= %.0f), open interest >= %s, \
                    spread <= %s of mid, %d-%d days to expiry, |delta| %s-%s."
      max_ask (max_ask *. 100.0) oi_text (pct 0 max_spread) min_days max_days
      (py_float delta_lo) (py_float delta_hi);
    "- need% = stock move to break even at expiry. hist_BE = share of past windows of the same length with at";
    "  least that move. hist_2x = share where the option ends worth twice its cost. hist_payoff = average expiry";
    "  value / cost over those windows (above 1.00 means history paid more than today's price).";
    "- CAUTION: windows overlap and include the stock's past drift. A past bull run inflates every call column";
    "  and deflates every put column.";
    ""; "## Calls"; "" ] @ table calls @ [""; "## Puts"; ""] @ table puts in
  print_string (String.concat "\n" out ^ "\n")

(* ---- value: Black-Scholes, European, no dividends ---- *)
let ncdf x = 0.5 *. (1.0 +. Float.erf (x /. sqrt 2.0))

let intrinsic kind s k = if kind = 'P' then Float.max (k -. s) 0.0 else Float.max (s -. k) 0.0

let bs kind s k t vol r =
  if t <= 0.0 then intrinsic kind s k
  else
    let d1 = (log (s /. k) +. (r +. 0.5 *. vol *. vol) *. t) /. (vol *. sqrt t) in
    let d2 = d1 -. vol *. sqrt t in
    if kind = 'P' then k *. exp (-. r *. t) *. ncdf (-. d2) -. s *. ncdf (-. d1)
    else s *. ncdf d1 -. k *. exp (-. r *. t) *. ncdf d2

(* bisection on [0.01, 3.0], 80 halvings; price rises with vol for both kinds *)
let implied_vol kind price s k t r =
  let rec go lo hi i =
    if i = 0 then 0.5 *. (lo +. hi)
    else
      let mid = 0.5 *. (lo +. hi) in
      if bs kind s k t mid r > price then go lo mid (i - 1) else go mid hi (i - 1) in
  go 0.01 3.0 80

let value_cmd ~chain_path ~ticker ~expiry ~strike ~kind ~at ~on ~rate =
  let chain = load_chain chain_path in
  let ki = int_of_float (Float.round (strike *. 1000.0)) in
  let yymmdd = String.sub (String.concat "" (String.split_on_char '-' (iso_of_day expiry))) 2 6 in
  let symbol = Printf.sprintf "%s%s%c%08d" ticker yymmdd kind ki in
  let leg = match List.find_opt (fun o -> member "option" o = Str symbol) chain.options with
    | Some o -> o
    | None -> die (Printf.sprintf "%s: no contract %s" chain_path symbol) in
  let bid_j = member "bid" leg and ask_j = member "ask" leg in
  let bid = num_or0 bid_j and ask = num_or0 ask_j in
  let mid = 0.5 *. (bid +. ask) in
  if mid <= 0.0 then die (symbol ^ ": no bid/ask quote to back vol out of");
  let days0 = expiry - chain.today and days = expiry - on in
  let t0 = float_of_int days0 /. 365.0 and t = float_of_int days /. 365.0 in
  if t0 <= 0.0 then die (symbol ^ ": expired on the feed date");
  let vol = implied_vol kind mid chain.spot strike t0 rate in
  let kname = if kind = 'P' then "put" else "call" in
  Printf.printf "%s %s %g %s\n" ticker (iso_of_day expiry) strike kname;
  Printf.printf "- Contract %s. Cboe delayed feed, %s UTC. Spot %s.\n" symbol chain.stamp chain.spot_text;
  Printf.printf "- Bid %s, ask %s, mid %.2f, spread %s of mid, OI %s, feed iv %s.\n"
    (py_num bid_j) (py_num ask_j) mid (pct 0 ((ask -. bid) /. mid))
    (py_num (member "open_interest" leg)) (py_num (member "iv" leg));
  Printf.printf "- Backed-out vol %.3f from the mid, %d days to expiry, rate %s (assumed, not quoted).\n"
    vol days0 (py_float rate);
  if vol < 0.0101 || vol > 2.999 then
    print_endline "- WARNING: backed-out vol sits at the search bound; the mid is outside the model's range.";
  print_endline "- Model: Black-Scholes, European exercise, no dividends.";
  print_endline "";
  Printf.printf "Stock at %s on %s (%d days to expiry):\n" (py_float at) (iso_of_day on) days;
  print_endline "";
  print_endline "| vol | value | holding to expiry pays more beyond |";
  print_endline "|---|--:|--:|";
  List.iter (fun (name, bump) ->
    let v = bs kind at strike t (vol +. bump) rate in
    let beyond = if kind = 'P' then strike -. v else strike +. v in
    Printf.printf "| %s (%.3f) | %.2f | stock %s %.2f |\n"
      name (vol +. bump) v (if kind = 'P' then "below" else "above") beyond)
    [ ("same", 0.0); ("+5 pts", 0.05); ("+10 pts", 0.10) ];
  Printf.printf "| intrinsic | %.2f | |\n" (intrinsic kind at strike)

(* ---- drawdown and corr: falls and co-movement in daily adjusted closes ---- *)
type fall = { peak : int; trough : int; depth : float; recovered : int option }

(* one fall per drawdown episode: an episode opens at a close at or above every earlier
   close and ends at the next such close, so episodes never overlap. Indexes, not days.
   Sorted deepest first; ties keep date order. *)
let falls c =
  let eps = ref [] and p = ref 0 and tr = ref 0 in
  let close_ep recovered =
    if c.(!tr) < c.(!p) then
      eps := { peak = !p; trough = !tr; depth = c.(!tr) /. c.(!p) -. 1.0; recovered } :: !eps in
  for i = 1 to Array.length c - 1 do
    if c.(i) >= c.(!p) then (close_ep (Some i); p := i; tr := i)
    else if c.(i) < c.(!tr) then tr := i
  done;
  close_ep None;
  List.stable_sort (fun a b -> compare a.depth b.depth) (List.rev !eps)

let rec take n = function x :: tl when n > 0 -> x :: take (n - 1) tl | _ -> []

let falls_table days c eps =
  [ "| rank | peak | trough | peak close | trough close | fall | days down | days to recover |";
    "|--:|---|---|--:|--:|--:|--:|--:|" ]
  @ (if eps = [] then ["| - | no fall in the period | | | | | | |"]
     else List.mapi (fun i f ->
       Printf.sprintf "| %d | %s | %s | %.2f | %.2f | %s | %d | %s |"
         (i + 1) (iso_of_day days.(f.peak)) (iso_of_day days.(f.trough)) c.(f.peak) c.(f.trough)
         (pct_signed 1 f.depth) (f.trough - f.peak)
         (match f.recovered with Some r -> string_of_int (r - f.trough) | None -> "not recovered"))
       (take 3 eps))

let drawdown_cmd ~history_path ~ticker =
  let (days, c) = dated_history history_path in
  let n = Array.length c in
  if n < 2 then die (history_path ^ ": too few closes for a drawdown");
  let eps = falls c in
  let largest = match eps with
    | [] -> Printf.sprintf "- Largest fall: none; no close fell below an earlier high."
    | f :: _ ->
        Printf.sprintf "- Largest fall: %s, from %s (close %.2f) to %s (close %.2f), %d trading days down; %s."
          (pct_signed 1 f.depth) (iso_of_day days.(f.peak)) c.(f.peak)
          (iso_of_day days.(f.trough)) c.(f.trough) (f.trough - f.peak)
          (match f.recovered with
           | Some r -> Printf.sprintf "back to the old peak %d trading days later, on %s"
                         (r - f.trough) (iso_of_day days.(r))
           | None -> Printf.sprintf "not recovered by %s" (iso_of_day days.(n - 1))) in
  let out = [
    Printf.sprintf "# %s largest falls" ticker;
    "";
    Printf.sprintf "- Price history: Yahoo daily adjusted closes, %s to %s (%d days)."
      (iso_of_day days.(0)) (iso_of_day days.(n - 1)) n;
    "- Fall = peak-to-trough change in adjusted close. Day counts are trading days in the file.";
    largest;
    ""; "## Three largest non-overlapping falls"; "" ] @ falls_table days c eps in
  print_string (String.concat "\n" out ^ "\n")

let min_common = 30

(* Pearson correlation; None when either side has no variance *)
let pearson xs ys =
  let n = float_of_int (Array.length xs) in
  let mx = sum Fun.id xs /. n and my = sum Fun.id ys /. n in
  let sxy = ref 0.0 and sxx = ref 0.0 and syy = ref 0.0 in
  Array.iteri (fun i x ->
    let dx = x -. mx and dy = ys.(i) -. my in
    sxy := !sxy +. dx *. dy; sxx := !sxx +. dx *. dx; syy := !syy +. dy *. dy) xs;
  if !sxx = 0.0 || !syy = 0.0 then None else Some (!sxy /. sqrt (!sxx *. !syy))

let corr_text = function Some r -> Printf.sprintf "%.2f" r | None -> "n/a"

let corr_cmd ~a_path ~a ~b_path ~b =
  let (da, ca) = dated_history a_path and (db, cb) = dated_history b_path in
  (* merge-join on common days *)
  let common = ref [] and i = ref 0 and j = ref 0 in
  while !i < Array.length da && !j < Array.length db do
    if da.(!i) = db.(!j) then (common := (da.(!i), ca.(!i), cb.(!j)) :: !common; incr i; incr j)
    else if da.(!i) < db.(!j) then incr i
    else incr j
  done;
  let common = Array.of_list (List.rev !common) in
  let n = Array.length common in
  if n < min_common then
    die (Printf.sprintf "%s and %s share %d dates; need at least %d" a b n min_common);
  let days = Array.map (fun (d, _, _) -> d) common in
  let xa = Array.map (fun (_, x, _) -> x) common and xb = Array.map (fun (_, _, y) -> y) common in
  let ret x = Array.init (n - 1) (fun k -> x.(k + 1) /. x.(k) -. 1.0) in
  let ra = ret xa and rb = ret xb in
  (* returns grouped by the calendar year of the later date, in order *)
  let year k = String.sub (iso_of_day days.(k + 1)) 0 4 in
  let rec years k acc =
    if k >= n - 1 then List.rev acc
    else
      let y = year k in
      let rec stop e = if e < n - 1 && year e = y then stop (e + 1) else e in
      let e = stop k in
      years e ((y, k, e - k) :: acc) in
  let year_rows = List.map (fun (y, k, len) ->
    Printf.sprintf "| %s | %s | %d |" y
      (corr_text (pearson (Array.sub ra k len) (Array.sub rb k len))) len) (years 0 []) in
  let cross name other xs ys =
    [ ""; Printf.sprintf "## %s's three largest falls, and %s over the same dates" name other; "";
      Printf.sprintf "| peak | trough | %s fall | %s return |" name other; "|---|---|--:|--:|" ]
    @ (match falls xs with
       | [] -> [Printf.sprintf "| no fall in %s over the common dates | | | |" name]
       | eps -> List.map (fun f ->
           Printf.sprintf "| %s | %s | %s | %s |" (iso_of_day days.(f.peak)) (iso_of_day days.(f.trough))
             (pct_signed 1 f.depth) (pct_signed 1 (ys.(f.trough) /. ys.(f.peak) -. 1.0)))
           (take 3 eps)) in
  let span d = Printf.sprintf "%s to %s (%d days)" (iso_of_day d.(0)) (iso_of_day d.(Array.length d - 1)) (Array.length d) in
  let out = [
    Printf.sprintf "# %s vs %s daily-return correlation" a b;
    "";
    Printf.sprintf "- Price history: Yahoo daily adjusted closes. %s %s; %s %s." a (span da) b (span db);
    Printf.sprintf "- Common dates: %s, %d daily returns. Every figure below uses common dates only."
      (span days) (n - 1);
    Printf.sprintf "- Whole overlap: correlation %s over %d daily returns." (corr_text (pearson ra rb)) (n - 1);
    "- Falls are peak-to-trough in adjusted close; the other stock's return runs from the same peak date";
    "  to the same trough date.";
    ""; "## Correlation by calendar year"; "";
    "| year | correlation | days |"; "|---|--:|--:|" ]
    @ year_rows @ cross a b xa xb @ cross b a xb xa
    @ [""; "A low long-run correlation does not mean the two offset each other in a selloff."] in
  print_string (String.concat "\n" out ^ "\n")

(* ---- facts: one company's XBRL figures from the SEC company-facts JSON ---- *)
let annual_forms = ["10-K"; "10-K/A"; "20-F"; "20-F/A"; "40-F"; "40-F/A"]
let interim_forms = ["10-Q"; "10-Q/A"]
let annual_min_days = 350 and annual_max_days = 380

type fact = { fstart : int option; fend : int; fval : float; accn : string; form : string; filed : string }

(* a fact lacking an end date, value, accession, form or filed date is skipped *)
let fact_of j =
  let s k = match member k j with Str v -> Some v | _ -> None in
  match Option.bind (s "end") parse_iso, member "val" j, s "accn", s "form", s "filed" with
  | Some fend, Num (fval, _), Some accn, Some form, Some filed ->
      Some { fstart = Option.bind (s "start") parse_iso; fend; fval; accn; form; filed }
  | _ -> None

(* a period: annual (start None: any 350-380 day span ending at p_end) or interim
   (start Some s: exactly s to p_end); instants need only the end date *)
type period = { p_start : int option; p_end : int; forms : string list }

let in_period pk p f =
  List.mem f.form p.forms && f.fend = p.p_end &&
  match pk, f.fstart, p.p_start with
  | Instant, None, _ -> true
  | Flow, Some s, Some ps -> s = ps
  | Flow, Some s, None -> let d = f.fend - s in d >= annual_min_days && d <= annual_max_days
  | _ -> false

(* (newest, first) filing by filed date then accession; ties keep file order *)
let newest_first = function
  | [] -> None
  | f :: tl ->
      let key f = (f.filed, f.accn) in
      Some (List.fold_left (fun a f -> if key f > key a then f else a) f tl,
            List.fold_left (fun a f -> if key f < key a then f else a) f tl)

(* alts: in a [largest] part, every recipe with data for the period as (recipe, sum), in
   recipe order; [] in any other part *)
type comp = { tag : string; last : fact; orig : fact; alts : (string * float) list }
type cell =
  | Found of float * comp list * part list   (* value, tags summed, optional parts absent *)
  | Missing of string list                  (* recipes tried for the required part *)

let restated c = c.last.fval <> c.orig.fval
let recipe_text r = String.concat " + " r

(* the alternatives behind a found cell when its largest and smallest differ by more
   than 1 percent of the largest; [] otherwise *)
let differing comps =
  match List.find_opt (fun c -> List.length c.alts >= 2) comps with
  | None -> []
  | Some c ->
      let vs = List.map snd c.alts in
      let hi = List.fold_left Float.max Float.neg_infinity vs
      and lo = List.fold_left Float.min Float.infinity vs in
      if hi -. lo > 0.01 *. Float.abs hi then c.alts else []

(* look tag -> facts of that tag in the period *)
let resolve look parts =
  let read r =
    let cs = List.filter_map (fun t ->
      Option.map (fun (last, orig) -> { tag = t; last; orig; alts = [] }) (newest_first (look t))) r in
    if List.length cs = List.length r then Some cs else None in
  let total cs = List.fold_left (fun a c -> a +. c.last.fval) 0.0 cs in
  let try_part p =
    if not p.largest then List.find_map read p.recipes
    else
      let found = List.filter_map (fun r -> Option.map (fun cs -> (r, cs)) (read r)) p.recipes in
      match found with
      | [] -> None
      | f :: tl ->
          (* the largest sum; a tie keeps the earlier recipe *)
          let best = List.fold_left (fun a (_, cs) -> if total cs > total a then cs else a) (snd f) tl in
          let alts = List.map (fun (r, cs) -> (recipe_text r, total cs)) found in
          Some (List.map (fun c -> { c with alts }) best) in
  let rec go comps absent = function
    | [] -> Found (List.fold_left (fun a c -> a +. c.last.fval) 0.0 comps, comps, List.rev absent)
    | p :: rest ->
        match try_part p with
        | Some cs -> go (comps @ cs) absent rest
        | None when p.required -> Missing (List.map recipe_text p.recipes)
        | None -> go comps (p :: absent) rest in
  go [] [] parts

(* "1234567.8" -> "1,234,567.8" *)
let commas s =
  let neg = s <> "" && s.[0] = '-' in
  let s = if neg then String.sub s 1 (String.length s - 1) else s in
  let i = Option.value (String.index_opt s '.') ~default:(String.length s) in
  let b = Buffer.create 24 in
  if neg then Buffer.add_char b '-';
  String.iteri (fun k c ->
    if k < i && k > 0 && (i - k) mod 3 = 0 then Buffer.add_char b ',';
    Buffer.add_char b c) s;
  Buffer.contents b

let fmt_value uk v =
  match uk with
  | Per_share -> Printf.sprintf "%.2f" v
  | Money | Shares -> commas (Printf.sprintf "%.1f" (v /. 1e6))

let dedup l = List.fold_left (fun acc x -> if List.mem x acc then acc else acc @ [x]) [] l

(* a found cell's notes as " (a; b)", or "" *)
let cell_notes comps absent =
  let notes = dedup ((if List.exists restated comps then ["restated"] else [])
                     @ List.filter_map (fun c -> List.assoc_opt c.tag tag_notes) comps
                     @ List.map (fun p -> p.part ^ " not tagged, not added") absent
                     @ (if differing comps <> [] then ["tags differ, largest shown; see note"] else [])) in
  if notes = [] then "" else " (" ^ String.concat "; " notes ^ ")"

let cell_text uk = function
  | Missing _ -> "NOT FOUND"
  | Found (v, comps, absent) -> fmt_value uk v ^ cell_notes comps absent

let cite_rows uk label ptext = function
  | Missing tried ->
      [ Printf.sprintf "| %s | %s | NOT FOUND | | | | | tried: %s |" label ptext (String.concat ", " tried) ]
  | Found (_, comps, absent) ->
      List.map (fun c ->
        let notes =
          (if restated c then [Printf.sprintf "restated; first filed %s on %s (%s)"
                                 (fmt_value uk c.orig.fval) c.orig.filed c.orig.accn] else [])
          @ Option.to_list (List.assoc_opt c.tag tag_notes) in
        Printf.sprintf "| %s | %s | %s | %s | %s | %s | %s | %s |" label ptext c.tag
          (fmt_value uk c.last.fval) c.last.accn c.last.form c.last.filed (String.concat "; " notes)) comps
      @ List.map (fun p ->
          Printf.sprintf "| %s | %s | %s: none tagged | | | | | tried: %s; not added |" label ptext
            p.part (String.concat ", " (List.map recipe_text p.recipes))) absent

(* one company-facts file, read once: the taxonomy and currency chosen, the fiscal year
   ends, every fact under the listed tags, and the cell of any concept in any period *)
type facts_file = {
  entity : string; cik : string; tax : string; cur : string;
  concepts : concept list; fy_ends : int list;
  every : (concept * fact) list;
  cell : concept -> period -> cell;
  parts_of : concept -> part list }

let load_facts path =
  let raw = load_json path in
  let fobj = match member "facts" raw with
    | Obj _ as o -> o
    | _ -> die (path ^ ": no \"facts\" object; not a company-facts file") in
  let entity = match member "entityName" raw with Str s -> s | _ -> "(no entityName)" in
  let cik = match member "cik" raw with
    | Num (f, _) -> Printf.sprintf "%010.0f" f
    | Str s when String.length s <= 10 && s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s ->
        String.make (10 - String.length s) '0' ^ s
    | Str s -> s
    | _ -> "(no cik)" in
  let concepts = List.filter_map (function Tagged c -> Some c | Free_cash_flow -> None) concept_table in
  let parts_of tax c = if tax = "ifrs-full" then c.ifrs else c.gaap in
  let tags_of tax c = dedup (List.concat_map (fun p -> List.concat p.recipes) (parts_of tax c)) in
  let units tax tag = match member "units" (member tag (member tax fobj)) with Obj l -> l | _ -> [] in
  (* taxonomy: the one holding more facts under the listed tags; a tie goes to us-gaap *)
  let count tax = List.fold_left (fun a c ->
    List.fold_left (fun a t ->
      List.fold_left (fun a (_, v) -> match v with Arr l -> a + List.length l | _ -> a) a (units tax t))
      a (tags_of tax c)) 0 concepts in
  let ng = count "us-gaap" and ni = count "ifrs-full" in
  if ng = 0 && ni = 0 then die (path ^ ": no us-gaap or ifrs-full facts under any listed tag");
  let tax = if ni > ng then "ifrs-full" else "us-gaap" in
  (* currency: the money unit with the most facts under the money concepts' tags; a tie
     goes to the alphabetically first unit *)
  let cur_counts = Hashtbl.create 8 in
  List.iter (fun c -> if c.uk = Money then
    List.iter (fun t -> List.iter (fun (u, v) ->
      match v with
      | Arr l when not (String.contains u '/') && u <> "shares" && u <> "pure" ->
          Hashtbl.replace cur_counts u (List.length l + Option.value (Hashtbl.find_opt cur_counts u) ~default:0)
      | _ -> ()) (units tax t)) (tags_of tax c)) concepts;
  let cur = match List.sort (fun (u1, n1) (u2, n2) -> compare (n2, u1) (n1, u2))
                    (List.of_seq (Hashtbl.to_seq cur_counts)) with
    | (u, _) :: _ -> u
    | [] -> die (path ^ ": no money unit under the " ^ tax ^ " tags") in
  let unit_of c = match c.uk with Money -> cur | Per_share -> cur ^ "/shares" | Shares -> "shares" in
  let cache = Hashtbl.create 64 in
  let facts_of_tag c t =
    let u = unit_of c in
    match Hashtbl.find_opt cache (t, u) with
    | Some l -> l
    | None ->
        let l = match List.assoc_opt u (units tax t) with
          | Some (Arr l) -> List.filter_map fact_of l | _ -> [] in
        Hashtbl.add cache (t, u) l; l in
  let all_facts c = List.concat_map (facts_of_tag c) (tags_of tax c) in
  let every = List.concat_map (fun c -> List.map (fun f -> (c, f)) (all_facts c)) concepts in
  (* fiscal years: the end dates of annual-span money flows in annual forms *)
  let fy_ends = List.sort_uniq compare (List.concat_map (fun c ->
    if c.pk = Flow && c.uk = Money then
      List.filter_map (fun f ->
        if in_period Flow { p_start = None; p_end = f.fend; forms = annual_forms } f then Some f.fend else None)
        (all_facts c)
    else []) concepts) in
  let cell c p = resolve (fun t -> List.filter (in_period c.pk p) (facts_of_tag c t)) (parts_of tax c) in
  { entity; cik; tax; cur; concepts; fy_ends; every; cell; parts_of = parts_of tax }

let facts_cmd ~path ~ticker ~years =
  let { entity; cik; tax; cur; concepts; fy_ends; every; cell; parts_of } = load_facts path in
  let anchor = match List.rev fy_ends with e :: _ -> Some e | [] -> None in
  let n_all = List.length fy_ends in
  let shown = List.filteri (fun i _ -> i >= n_all - years) fy_ends in
  (* the newest filing among facts passing [keep]: (form, accession, filed, max end in it) *)
  let newest_filing keep =
    let fs = List.filter_map (fun (c, f) -> if keep c f then Some f else None) every in
    Option.map (fun (f, _) ->
      (f.form, f.accn, f.filed,
       List.fold_left (fun a g -> if g.accn = f.accn then max a g.fend else a) f.fend fs))
      (newest_first fs) in
  let annual_filing = newest_filing (fun _ f -> List.mem f.form annual_forms) in
  let interim_filing = newest_filing (fun _ f ->
    List.mem f.form interim_forms && (match anchor with Some a -> f.fend > a | None -> true)) in
  (* the interim flow start: the day after the newest fiscal year end, or with no annual
     period the earliest start among that filing's flows ending at its period end *)
  let interim = Option.map (fun (form, accn, filed, e) ->
    let start = match anchor with
      | Some a -> Some (a + 1)
      | None ->
          List.fold_left (fun acc (c, f) ->
            match f.fstart with
            | Some s when c.pk = Flow && f.accn = accn && f.fend = e ->
                Some (match acc with Some m -> min m s | None -> s)
            | _ -> acc) None every in
    (form, accn, filed, e, start)) interim_filing in
  (* one column: (concept label, cell text, citation rows) per table entry, and the notes
     for cells whose largest-wins tags differ *)
  let column p ptext =
    let cells = List.map (fun c -> (c.label, (c, cell c p))) concepts in
    let notes = List.filter_map (fun (_, (c, x)) ->
      match x with
      | Found (_, comps, _) when differing comps <> [] ->
          Some (Printf.sprintf "- %s tags differ for %s: %s; the largest is shown; check the income statement."
                  (String.lowercase_ascii c.label) ptext
                  (String.concat ", " (List.map (fun (r, v) -> r ^ " " ^ fmt_value c.uk v) (differing comps))))
      | _ -> None) cells in
    (notes, List.map (function
      | Tagged c ->
          let x = List.assoc c.label cells |> snd in
          (c.label, cell_text c.uk x, cite_rows c.uk c.label ptext x)
      | Free_cash_flow ->
          let label = "Free cash flow (computed)" in
          (match snd (List.assoc ocf_label cells), snd (List.assoc capex_label cells) with
           | Found (o, oc, _), Found (k, kc, _) ->
               let v = o -. k in
               let r = List.exists restated (oc @ kc) in
               (label, fmt_value Money v ^ (if r then " (restated input)" else ""),
                [ Printf.sprintf "| %s | %s | computed: %s minus %s | %s | | | | from the two cited rows |"
                    label ptext ocf_label capex_label (fmt_value Money v) ])
           | _ ->
               (label, "NOT FOUND",
                [ Printf.sprintf "| %s | %s | NOT FOUND | | | | | needs both %s and %s |"
                    label ptext ocf_label capex_label ])))
      concept_table) in
  (* the table, then its columns' notes *)
  let table cols =
    let heads = List.map fst cols and data = List.map (fun (_, (_, d)) -> d) cols in
    let notes = List.concat_map (fun (_, (n, _)) -> n) cols in
    (Printf.sprintf "| concept | %s |" (String.concat " | " heads))
    :: (Printf.sprintf "|---|%s" (String.concat "" (List.map (fun _ -> "--:|") heads)))
    :: List.mapi (fun i e ->
         let label = match e with Tagged c -> c.label | Free_cash_flow -> "Free cash flow (computed)" in
         Printf.sprintf "| %s | %s |" label
           (String.concat " | " (List.map (fun col -> let (_, t, _) = List.nth col i in t) data)))
       concept_table
    @ (if notes = [] then [] else "" :: notes) in
  let annual_cols = List.map (fun e ->
    (iso_of_day e, column { p_start = None; p_end = e; forms = annual_forms } ("FY " ^ iso_of_day e))) shown in
  let interim_col = Option.map (fun (_, _, _, e, start) ->
    (* no start known: a start no fact can carry, so every flow reads NOT FOUND *)
    let p = { p_start = Some (Option.value start ~default:min_int); p_end = e; forms = interim_forms } in
    (iso_of_day e, column p ("interim " ^ iso_of_day e))) interim in
  let debt_text = String.concat " + " (List.concat_map (fun c ->
    if c.label = "Total debt" then List.map (fun p -> if p.required then p.part else p.part ^ " (when tagged)")
                                     (parts_of c) else []) concepts) in
  let head = [
    Printf.sprintf "# %s reported figures (SEC company facts)" ticker;
    "";
    Printf.sprintf "- Entity: %s, CIK %s. File: company-facts JSON." entity cik;
    Printf.sprintf "- Taxonomy: %s. Currency: %s. Amounts in %s millions; shares in millions; \
                    per-share figures in %s." tax cur cur cur;
    (match annual_filing with
     | Some (form, accn, filed, e) ->
         Printf.sprintf "- Newest annual filing: %s for the period ending %s, filed %s, accession %s."
           form (iso_of_day e) filed accn
     | None -> "- Newest annual filing: none; no 10-K, 20-F or 40-F fact under the listed tags.");
    Printf.sprintf "- Annual flows: facts from forms %s spanning %d to %d days. Balances: the value \
                    at the fiscal year end from the same forms." (String.concat ", " annual_forms)
      annual_min_days annual_max_days;
    "- A period reported in several filings uses the most recent filing; \"restated\" marks a value";
    "  that differs from the first filing's. NOT FOUND: no listed tag has a fact for that period.";
    Printf.sprintf "- Total debt = %s; the citations name the tags summed in each cell." debt_text;
    Printf.sprintf "- Free cash flow is computed here (%s minus %s), not a filed figure." ocf_label capex_label;
  ] in
  let annual_part =
    [""; Printf.sprintf "## Annual, fiscal years ending (%d of %d found)" (List.length shown) n_all; ""]
    @ (if shown = [] then ["No annual period found: no 10-K, 20-F or 40-F flow fact spanning a year."]
       else table annual_cols) in
  let interim_part = match interim, interim_col with
    | Some (form, accn, filed, e, start), Some col ->
        let span = match start with
          | None -> "no flow fact ends on the period end, so flow items read NOT FOUND."
          | Some s ->
              let d = e - s in
              let q = (d + 45) / 91 in
              let what =
                if q <= 1 then
                  (if anchor <> None then "one quarter, the first of the fiscal year, so also year-to-date"
                   else "one quarter")
                else if anchor <> None then Printf.sprintf "year-to-date, about %d quarters" q
                else Printf.sprintf "the longest span in the filing, read as year-to-date, about %d quarters" q in
              Printf.sprintf "flow items run %s to %s (%d days): %s." (iso_of_day s) (iso_of_day e) d what in
        [""; Printf.sprintf "## Newest interim period, ending %s" (iso_of_day e); "";
         Printf.sprintf "- %s filed %s, accession %s%s." form filed accn
           (match anchor with
            | Some a -> Printf.sprintf ", after the fiscal year ending %s" (iso_of_day a)
            | None -> "; no annual period in the file");
         "- Balances at " ^ iso_of_day e ^ "; " ^ span; ""]
        @ table [col]
    | _ ->
        [""; "## Newest interim period"; "";
         "None: no 10-Q fact under the listed tags ends after the newest fiscal year end."] in
  let cites =
    [""; "## Citations"; "";
     "| concept | period | tag | value | accession | form | filed | note |";
     "|---|---|---|--:|---|---|---|---|"]
    @ List.concat_map (fun (_, (_, col)) -> List.concat_map (fun (_, _, rows) -> rows) col)
        (annual_cols @ Option.to_list interim_col) in
  let tail =
    [""; "Figures come from the company's own XBRL tags; a tag can be mis-assigned by the filer; \
          check a figure against the filing text before relying on it for a decision."] in
  print_string (String.concat "\n" (head @ annual_part @ interim_part @ cites @ tail) ^ "\n")

(* ---- book: the holdings replayed at today's mix, cash held outside ---- *)
type position = { tk : string; value : float; path : string }

(* whole dollars with thousands commas; a rounded -0 prints as 0 *)
let money v = let s = Printf.sprintf "%.0f" v in commas (if s = "-0" then "0" else s)

(* the dates present in every history, ascending, and each history's closes on them;
   a date repeated in one file keeps its last close *)
let common_dates hs =
  let tbls = List.map (fun (d, c) ->
    let h = Hashtbl.create (Array.length d) in
    Array.iteri (fun k x -> Hashtbl.replace h x c.(k)) d; h) hs in
  let d0 = match hs with (d, _) :: _ -> Array.to_list d | [] -> [] in
  let days = Array.of_list (List.sort_uniq compare
    (List.filter (fun x -> List.for_all (fun h -> Hashtbl.mem h x) tbls) d0)) in
  (days, Array.of_list (List.map (fun h -> Array.map (Hashtbl.find h) days) tbls))

(* constant-weight replay: holding i at weight w.(i), rebalanced daily; weights that sum
   below 1 leave the rest at a 0 return. rets.(i).(t) runs from common date t to t + 1.
   The index is scaled so its last value is [total]. *)
let replay ~rets ~total w =
  let k = Array.length w and m = Array.length rets.(0) in
  let idx = Array.make (m + 1) 1.0 in
  for t = 1 to m do
    let r = ref 0.0 in
    for i = 0 to k - 1 do r := !r +. w.(i) *. rets.(i).(t - 1) done;
    idx.(t) <- idx.(t - 1) *. (1.0 +. !r)
  done;
  let last = idx.(m) in
  Array.map (fun x -> x *. total /. last) idx

(* a pair is a suggested link at or above this correlation over the recent years *)
let link_corr = 0.50

(* the day n calendar years before day z; 29 February maps to 1 March *)
let years_before z n =
  let tm = Unix.gmtime (float_of_int z *. 86400.0) in
  days_from_civil (tm.Unix.tm_year + 1900 - n) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

let book_cmd ~positions ~cash ~tolerance ~corr_years =
  let pos = Array.of_list positions in
  let k = Array.length pos in
  let hs = Array.of_list (List.map (fun p -> dated_history p.path) positions) in
  let (days, closes) = common_dates (Array.to_list hs) in
  let n = Array.length days in
  if n < min_common then
    die (Printf.sprintf "the %d histories share %d dates; need at least %d" k n min_common);
  let values = Array.map (fun p -> p.value) pos in
  let invested = Array.fold_left ( +. ) 0.0 values in
  let total = invested +. cash in
  let w = Array.map (fun v -> v /. invested) values in
  let rets = Array.map (fun c -> Array.init (n - 1) (fun t -> c.(t + 1) /. c.(t) -. 1.0)) closes in
  (* holding i at scale.(i) of today's value, the value removed added to the fixed cash:
     (invested value, weights within it, its index scaled to that value) *)
  let run scale =
    let vs = Array.mapi (fun i v -> v *. scale.(i)) values in
    let inv = Array.fold_left ( +. ) 0.0 vs in
    let ws = Array.map (fun v -> if inv > 0.0 then v /. inv else 0.0) vs in
    (inv, ws, replay ~rets ~total:inv ws) in
  let p = replay ~rets ~total:invested w in
  let span = Printf.sprintf "%s to %s (%d days)" (iso_of_day days.(0)) (iso_of_day days.(n - 1)) n in
  let head = [
    Printf.sprintf "# Portfolio replay: %d holding%s plus cash" k (if k = 1 then "" else "s");
    "";
    Printf.sprintf "- Price history: Yahoo daily adjusted closes. Common dates: %s." span;
    Printf.sprintf "- First date in the replay: %s. Falls before %s are not in the replay."
      (iso_of_day days.(0)) (iso_of_day days.(0));
    "- Cash is a fixed dollar amount outside the replay, the holdings are rebalanced daily among";
    "  themselves to today's mix, and each fall is shown as a percent of the invested part and as a";
    "  percent of the whole portfolio including cash.";
    "- Every past day applies today's mix to that day's returns, so a holding that has since risen";
    "  counts at its size today.";
    Printf.sprintf "- Invested today: %s. Cash: %s. Portfolio: %s. Dollar figures are at today's sizes."
      (money invested) (money cash) (money total);
    "";
    "| holding | value | % of invested part | % of portfolio |";
    "|---|--:|--:|--:|" ]
    @ List.init k (fun i ->
        Printf.sprintf "| %s | %s | %s | %s |" pos.(i).tk (money values.(i)) (pct 1 w.(i))
          (pct 1 (values.(i) /. total)))
    @ [ Printf.sprintf "| cash | %s | | %s |" (money cash) (pct 1 (cash /. total));
        Printf.sprintf "| total | %s | 100.0%% | 100.0%% |" (money total) ] in
  (* holding i's share of the move from date index a to b, in dollars at invested value
     [inv]: inv x sum of wi x ri(t) x index(t-1) / index(a) *)
  let contrib inv wi p a b i =
    let s = ref 0.0 in
    for t = a + 1 to b do s := !s +. wi.(i) *. rets.(i).(t - 1) *. (p.(t - 1) /. p.(a)) done;
    inv *. !s in
  let eps = falls p in
  let fall_block rank f =
    let dollars = f.depth *. invested in
    let cs = List.init k (fun i -> contrib invested w p f.peak f.trough i) in
    let resid = List.fold_left ( +. ) 0.0 cs -. dollars in
    [ ""; Printf.sprintf "### %d. %s to %s: %s of the invested part, %s of the portfolio incl. cash, %s"
            rank (iso_of_day days.(f.peak)) (iso_of_day days.(f.trough))
            (pct_signed 1 f.depth) (pct_signed 1 (dollars /. total)) (money dollars);
      "";
      Printf.sprintf "- %d trading days down; %s." (f.trough - f.peak)
        (match f.recovered with
         | Some r -> Printf.sprintf "back to the peak value on %s" (iso_of_day days.(r))
         | None -> Printf.sprintf "not recovered by %s" (iso_of_day days.(n - 1)));
      "";
      "| holding | contribution | share of the fall |"; "|---|--:|--:|" ]
    @ List.mapi (fun i c ->
        Printf.sprintf "| %s | %s | %s |" pos.(i).tk (money c) (pct 1 (c /. dollars))) cs
    @ [ "| cash | 0 | 0.0% |";
        Printf.sprintf "| total | %s | 100.0%% |" (money dollars) ]
    @ (if Float.abs resid > 0.01 then
         [""; Printf.sprintf "- Contributions differ from the fall by %.2f (rounding)." resid]
       else []) in
  let falls_part =
    [ ""; "## Three largest non-overlapping portfolio falls"; "";
      "- Same episode rule as `drawdown`, applied to the invested part's constant-weight index. The";
      "  dollar fall = the invested-part fall x today's invested value; the portfolio percent = that";
      "  dollar fall / today's portfolio including cash. Contribution of a holding = today's invested";
      "  value x the sum over the fall's days of its weight x its daily return x the index the day";
      "  before / the index at the peak; they sum to the dollar fall." ]
    @ (if eps = [] then [""; "No fall: the portfolio value never closed below an earlier high."]
       else List.concat (List.mapi (fun i f -> fall_block (i + 1) f) (take 3 eps))) in
  (* evidence for one-bet links, each pair on its own common dates *)
  let pair_evidence a b =
    let (pd, pc) = common_dates [hs.(a); hs.(b)] in
    let m = Array.length pd in
    let ret c = Array.init (m - 1) (fun t -> c.(t + 1) /. c.(t) -. 1.0) in
    let ra = ret pc.(0) and rb = ret pc.(1) in
    let cutoff = years_before pd.(m - 1) corr_years in
    (* returns starting on or after the cutoff date; all of them when the history is shorter *)
    let short = pd.(0) > cutoff in
    let s0 = if short then 0
             else let rec go t = if pd.(t) >= cutoff then t else go (t + 1) in go 0 in
    let recent = pearson (Array.sub ra s0 (m - 1 - s0)) (Array.sub rb s0 (m - 1 - s0)) in
    (* the three largest falls of xs, the other's return over each, and whether it fell
       at least half as far *)
    let cross xs ys = List.map (fun f ->
      let o = ys.(f.trough) /. ys.(f.peak) -. 1.0 in (f, o, o <= 0.5 *. f.depth))
      (take 3 (falls xs)) in
    let fa = cross pc.(0) pc.(1) and fb = cross pc.(1) pc.(0) in
    let halves l = List.length (List.filter (fun (_, _, h) -> h) l) in
    (pd, short, pearson ra rb, recent, fa, fb, halves fa, halves fb) in
  let pairs = List.concat (List.init k (fun a -> List.init (k - a - 1) (fun d ->
    let b = a + d + 1 in (a, b, pair_evidence a b)))) in
  let recent_label = Printf.sprintf "last %d year%s" corr_years (if corr_years = 1 then "" else "s") in
  let evidence_part =
    [ ""; "## Evidence for one-bet links"; "" ]
    @ (if k < 2 then ["One holding: nothing to pair."]
       else
         [ "- Each pair uses the dates both holdings share, which can start before the replay. Correlation";
           Printf.sprintf "  is of daily returns; the %s figure uses the returns from %d calendar years before"
             recent_label corr_years;
           "  the pair's last common date, or the whole common history when it is shorter.";
           "- Co-falls: during each holding's three largest falls on the pair's common dates, the other's";
           "  return from the same peak date to the same trough date; \"half\" counts the falls in which";
           "  the other fell at least half as far.";
           "";
           Printf.sprintf "| pair | common dates | correlation, whole | correlation, %s | co-falls |" recent_label;
           "|---|---|--:|--:|---|" ]
         @ List.map (fun (a, b, (pd, short, whole, recent, fa, fb, ha, hb)) ->
             let m = Array.length pd in
             Printf.sprintf "| %s-%s | %s to %s (%d days) | %s | %s | %s: %s half in %d of its %d falls; %s: %s half in %d of %d |"
               pos.(a).tk pos.(b).tk (iso_of_day pd.(0)) (iso_of_day pd.(m - 1)) m (corr_text whole)
               (corr_text recent ^ (if short then Printf.sprintf " (only %.1f years shared; all used)"
                                                     (float_of_int (pd.(m - 1) - pd.(0)) /. 365.25) else ""))
               pos.(a).tk pos.(b).tk ha (List.length fa) pos.(b).tk pos.(a).tk hb (List.length fb)) pairs
         @ List.concat_map (fun (a, b, (pd, _, _, _, fa, fb, _, _)) ->
             let rows name other l =
               if l = [] then [Printf.sprintf "| %s | no fall on the common dates | | | | |" name]
               else List.map (fun (f, o, h) ->
                 Printf.sprintf "| %s | %s | %s | %s | %s %s | %s |" name (iso_of_day pd.(f.peak))
                   (iso_of_day pd.(f.trough)) (pct_signed 1 f.depth) other (pct_signed 1 o)
                   (if h then "yes" else "no")) l in
             [ ""; Printf.sprintf "### %s-%s: each one's three largest falls, and the other's return" pos.(a).tk pos.(b).tk;
               "";
               "| fell | peak | trough | its fall | the other's return | other fell at least half as far |";
               "|---|---|---|--:|--:|---|" ]
             @ rows pos.(a).tk pos.(b).tk fa @ rows pos.(b).tk pos.(a).tk fb) pairs) in
  let suggested = List.filter_map (fun (a, b, (_, _, _, recent, fa, fb, ha, hb)) ->
    let by_corr = match recent with Some r -> r >= link_corr | None -> false in
    let reasons =
      (if by_corr then [Printf.sprintf "%s correlation %s" recent_label (corr_text recent)] else [])
      @ (if ha >= 2 then [Printf.sprintf "%s fell at least half as far in %d of %s's %d largest falls"
                            pos.(b).tk ha pos.(a).tk (List.length fa)] else [])
      @ (if hb >= 2 then [Printf.sprintf "%s fell at least half as far in %d of %s's %d largest falls"
                            pos.(a).tk hb pos.(b).tk (List.length fb)] else []) in
    if reasons = [] then None
    else Some (Printf.sprintf "- %s-%s: %s." pos.(a).tk pos.(b).tk (String.concat "; " reasons))) pairs in
  let links_part =
    if k < 2 then []
    else
      [ ""; "## Suggested links"; "";
        "These are suggestions from price history, not clusters. The caller names the clusters, using";
        "this evidence and what the filings say.";
        "";
        Printf.sprintf "- Rule: a pair is suggested when its %s correlation is at or above %.2f, or when"
          recent_label link_corr;
        "  the other fell at least half as far in two of the three largest falls of either holding.";
        "" ]
      @ (if suggested = [] then ["None: no pair meets either test."] else suggested) in
  (* limits at the tolerance, which is a fall in percent of the portfolio including cash *)
  let limit_part = match tolerance with
    | None -> [ ""; "No --tolerance given: no limits computed." ]
    | Some tol ->
        let depth_of = function f :: _ -> f.depth | [] -> 0.0 in
        (* (invested-part fall, portfolio fall incl. cash, invested value, weights, index) *)
        let worst scale =
          let (inv, ws, q) = run scale in
          let d = depth_of (falls q) in
          (d, d *. inv /. total, inv, ws, q) in
        let port scale = let (_, d, _, _, _) = worst scale in d in
        let fits scale = -. port scale <= tol in
        let f0 = depth_of eps in
        let w0 = f0 *. invested /. total in
        let head_lines =
          [ ""; Printf.sprintf "## Limits at a tolerance of %s of the portfolio including cash" (pct 1 tol); "";
            Printf.sprintf "- Worst replayed fall: %s of the invested part, %s of the portfolio including cash;"
              (pct_signed 1 f0) (pct_signed 1 w0);
            Printf.sprintf "  %s the tolerance." (if -. w0 <= tol then "inside" else "outside") ] in
        if -. w0 <= tol then head_lines @ ["- Inside the tolerance at today's sizes: no limit to compute."]
        else begin
          (* every holding scaled by one factor s keeps the invested mix, so the invested
             part still falls f0 and the portfolio falls f0 x s x invested / total *)
          let s = tol *. total /. (-. f0 *. invested) in
          let moved = invested *. (1.0 -. s) in
          let scale_of i x = Array.init k (fun j -> if j = i then x else 1.0) in
          let row i =
            let v = values.(i) in
            if not (fits (scale_of i 0.0)) then begin
              let (_, d, inv, ws, q) = worst (scale_of i 0.0) in
              let who = match falls q with
                | [] -> ""
                | f :: _ ->
                    let best = ref (-1) and bc = ref 0.0 in
                    for j = 0 to k - 1 do
                      let c = contrib inv ws q f.peak f.trough j in
                      if c < !bc then (best := j; bc := c)
                    done;
                    if !best < 0 then ""
                    else Printf.sprintf "; largest remaining contributor %s (%s)" pos.(!best).tk (money !bc) in
              Printf.sprintf "| %s | %s | cannot fit even at 0%s | | %s at 0 |" pos.(i).tk (money v) who
                (pct_signed 1 d)
            end else begin
              let lo = ref 0.0 and hi = ref 1.0 in
              for _ = 1 to 60 do
                let mid = 0.5 *. (!lo +. !hi) in
                if fits (scale_of i mid) then lo := mid else hi := mid
              done;
              let lim = v *. !lo in
              Printf.sprintf "| %s | %s | %s | %s | %s |" pos.(i).tk (money v) (money lim)
                (pct 1 (lim /. total)) (pct_signed 1 (port (scale_of i !lo)))
            end in
          head_lines
          @ [ Printf.sprintf "- Pro rata: scaling every holding to %s of its value moves %s to cash (cash then %s,"
                (pct 1 s) (money moved) (money (cash +. moved));
              Printf.sprintf "  %s of the portfolio). The invested part still falls %s, which is now %s of the"
                (pct 1 ((cash +. moved) /. total)) (pct_signed 1 f0) (pct_signed 1 (f0 *. s *. invested /. total));
              "  portfolio including cash. Scaling all holdings together keeps their mix, so the figure is";
              "  computed directly, not searched.";
              "";
              "### Information only: one holding scaled alone, the rest unchanged";
              "";
              "- Limit = the largest value of one holding at which the worst replayed fall stays inside the";
              "  tolerance, with the other holdings unchanged and the difference added to cash. Found by";
              "  bisection, re-running the replay at each step. Each row assumes the others stay unchanged,";
              "  so the rows do not add up; the pro-rata figure above is the one to use.";
              "";
              "| holding | value now | limit | limit % of portfolio | worst fall at the limit, % of portfolio |";
              "|---|--:|--:|--:|--:|" ]
          @ List.init k row
        end in
  let tail =
    [ ""; Printf.sprintf "A replay shows what these holdings did in the past at today's sizes; it is not a \
                          forecast, and a crash before %s is not in it." (iso_of_day days.(0)) ] in
  print_string (String.concat "\n" (head @ falls_part @ evidence_part @ links_part @ limit_part @ tail) ^ "\n")

(* ---- income: yearly dividend income against a need ---- *)
let cover_years = 3

let income_cmd ~holdings ~others ~need ~floor =
  let concept l = List.find (fun c -> c.label = l)
                    (List.filter_map (function Tagged c -> Some c | Free_cash_flow -> None) concept_table) in
  let dps_c = concept "Dividends declared per share" and paid_c = concept "Dividends paid"
  and ocf_c = concept ocf_label and capex_c = concept capex_label in
  let annual e = { p_start = None; p_end = e; forms = annual_forms } in
  let value_of = function Found (v, _, _) -> Some v | Missing _ -> None in
  (* per holding: (ticker, shares, dps cell and its fiscal year end, newest fiscal year end,
     cover rows) *)
  let rows = List.map (fun h ->
    let ff = load_facts h.path in
    if ff.cur <> "USD" then
      die (Printf.sprintf "%s: %s reports in %s; income adds US dollars only" h.path h.tk ff.cur);
    let newest = List.rev ff.fy_ends in
    let dps = List.find_map (fun e ->
      match ff.cell dps_c (annual e) with Found _ as c -> Some (e, c) | Missing _ -> None) newest in
    let cover = List.rev (List.map (fun e ->
      let get c = value_of (ff.cell c (annual e)) in
      (e, get ocf_c, get capex_c, get paid_c)) (take cover_years newest)) in
    (h, dps, (match newest with e :: _ -> Some e | [] -> None), cover)) holdings in
  let income_of (h, dps, _, _) = match dps with
    | Some (_, Found (v, _, _)) -> Some (v *. h.value) | _ -> None in
  let lines = List.map (fun r -> let (h, _, _, _) = r in (h.tk, income_of r)) rows
              @ List.map (fun (name, amt) -> (name, Some amt)) others in
  let total = List.fold_left (fun a (_, x) -> a +. Option.value x ~default:0.0) 0.0 lines in
  let share x = if total > 0.0 then pct 1 (x /. total) else "n/a" in
  let shares_text v = if Float.is_integer v then Printf.sprintf "%.0f" v else py_float v in
  let income_rows = List.map (fun ((h, dps, newest, _) as r) ->
    let (dps_text, fy) = match dps with
      | Some (e, c) ->
          ((match c with Found (v, comps, absent) -> py_float v ^ cell_notes comps absent
                       | Missing _ -> "NOT FOUND"),
           iso_of_day e ^ (match newest with
                           | Some n when n <> e -> Printf.sprintf " (newer year %s has no per-share tag)" (iso_of_day n)
                           | _ -> ""))
      | None -> ("NOT FOUND", "none with a per-share tag") in
    match income_of r with
    | Some x -> Printf.sprintf "| %s | %s | %s | %s | %s | %s |" h.tk (shares_text h.value) dps_text fy
                  (money x) (share x)
    | None -> Printf.sprintf "| %s | %s | %s | %s | NOT FOUND | |" h.tk (shares_text h.value) dps_text fy) rows
    @ List.map (fun (name, amt) ->
        Printf.sprintf "| %s | | | user-supplied | %s | %s |" name (money amt) (share amt)) others in
  let missing = List.filter_map (fun (t, x) -> if x = None then Some t else None) lines in
  let gap label target =
    let d = total -. target in
    Printf.sprintf "- %s %s a year: %s of %s a year." label (money target)
      (if d >= 0.0 then "surplus" else "shortfall") (money (Float.abs d)) in
  let ranked = List.stable_sort (fun (_, a) (_, b) -> compare b a)
                 (List.filter_map (fun (t, x) -> Option.map (fun x -> (t, x)) x) lines) in
  let top2 = take 2 ranked in
  let cover_value (_, ocf, capex, paid) = match ocf, capex, paid with
    | Some o, Some c, Some p when p > 0.0 -> Some ((o -. c) /. p)
    | _ -> None in
  let m v = match v with Some v -> fmt_value Money v | None -> "NOT FOUND" in
  let cover_rows = List.concat_map (fun (h, _, _, cover) ->
    if cover = [] then [Printf.sprintf "| %s | no fiscal year found | | | | | |" h.tk]
    else List.map (fun ((e, ocf, capex, paid) as y) ->
      let fcf = match ocf, capex with Some o, Some c -> Some (o -. c) | _ -> None in
      let cv = match cover_value y, paid with
        | Some v, _ -> Printf.sprintf "%.2f" v
        | None, Some p when p <= 0.0 && fcf <> None -> "n/a (no dividends paid)"
        | None, _ ->
            "NOT FOUND (" ^ String.concat ", " (List.filter_map (fun (l, x) -> if x = None then Some l else None)
                                                [ ("operating cash flow", ocf); ("capital expenditure", capex);
                                                  ("dividends paid", paid) ]) ^ ")" in
      Printf.sprintf "| %s | %s | %s | %s | %s | %s | %s |" h.tk (iso_of_day e) (m ocf) (m capex) (m fcf)
        (m paid) cv) cover) rows in
  let weak = List.filter_map (fun (h, _, _, cover) ->
    let under = List.length (List.filter (fun y ->
      match cover_value y with Some v -> v < 1.0 | None -> false) cover) in
    if under >= 2 then Some h.tk else None) rows in
  let incomplete = List.filter_map (fun (h, _, _, cover) ->
    let found = List.length (List.filter (fun y -> cover_value y <> None) cover) in
    if found < cover_years then Some (Printf.sprintf "%s (%d of %d)" h.tk found cover_years) else None) rows in
  let out = [
    "# Yearly dividend income";
    "";
    "- Dividend per share: the newest fiscal year with a declared (or, failing that, paid) per-share";
    "  tag in the company-facts file, same tags as `facts`, as filed. Yearly income = that figure x";
    "  shares, in whole dollars.";
    "- User-supplied income is taken as given and not checked.";
    "";
    "| holding | shares | dividend per share | fiscal year ending | yearly income | share of total |";
    "|---|--:|--:|---|--:|--:|" ]
    @ income_rows
    @ [ Printf.sprintf "| total | | | | %s | %s |" (money total) (if total > 0.0 then "100.0%" else "n/a");
        "";
        "## Against the need";
        "" ]
    @ (if missing = [] then []
       else [Printf.sprintf "- The total leaves out %s: no dividend per share found. Supply it with --other."
               (String.concat ", " missing)])
    @ [ gap "Need" need ]
    @ Option.to_list (Option.map (gap "Floor") floor)
    @ [ (match top2 with
         | [(a, x); (b, y)] -> Printf.sprintf "- Largest two payers: %s and %s, %s of the total." a b (share (x +. y))
         | [(a, x)] -> Printf.sprintf "- One payer: %s, %s of the total." a (share x)
         | _ -> "- No payer with a found income.");
        "";
        Printf.sprintf "## Cover: free cash flow / dividends paid, last %d fiscal years" cover_years;
        "";
        "- Free cash flow = operating cash flow minus capital expenditure, as in `facts`. Amounts in";
        "  millions. NOT FOUND names the missing part; nothing is estimated.";
        "";
        "| holding | fiscal year ending | operating cash flow | capital expenditure | free cash flow | dividends paid | cover |";
        "|---|---|--:|--:|--:|--:|--:|" ]
    @ cover_rows
    @ [ "";
        (if weak = [] then Printf.sprintf "- Cover under 1.00 in at least 2 of the last %d years: none." cover_years
         else Printf.sprintf "- Cover under 1.00 in at least 2 of the last %d years: %s." cover_years
                (String.concat ", " weak)) ]
    @ (if incomplete = [] then []
       else [Printf.sprintf "- Cover found for fewer than %d years, so the test above is partial: %s."
               cover_years (String.concat ", " incomplete)])
    @ [ "";
        "Cover is a weak predictor of a dividend cut.";
        "A low year can come from a one-off payment, so read the cash-flow notes before naming a weak payer." ] in
  print_string (String.concat "\n" out ^ "\n")

(* ---- command line ---- *)
let flags allowed args =
  let rec go acc = function
    | [] -> List.rev acc
    | k :: v :: tl when String.length k > 2 && String.sub k 0 2 = "--"
                        && List.mem (String.sub k 2 (String.length k - 2)) allowed ->
        go ((String.sub k 2 (String.length k - 2), v) :: acc) tl
    | _ -> bad_usage () in
  go [] args

let get fl k conv default =
  match List.assoc_opt k fl, default with
  | Some v, _ -> (match conv v with Some x -> x | None -> bad_usage ())
  | None, Some d -> d
  | None, None -> bad_usage ()

let str_opt s = if s = "" then None else Some s
let pos_float s = match float_of_string_opt s with Some f when f > 0.0 -> Some f | _ -> None
let kind_opt = function "P" | "p" -> Some 'P' | "C" | "c" -> Some 'C' | _ -> None
let pos_int s = match int_of_string_opt s with Some n when n > 0 -> Some n | _ -> None

(* each flag in [ks] at most once *)
let once fl ks =
  List.iter (fun k -> if List.length (List.filter (fun (k', _) -> k' = k) fl) > 1 then bad_usage ()) ks

(* split at the first c *)
let cut c s = Option.map (fun i -> (String.sub s 0 i, String.sub s (i + 1) (String.length s - i - 1)))
                (String.index_opt s c)

(* "TICKER=VALUE:FILE": split at the first '=' and then the first ':', so the file may
   itself hold ':'; VALUE is finite and above 0 *)
let parse_position s =
  match cut '=' s with
  | Some (tk, rest) when tk <> "" ->
      (match cut ':' rest with
       | Some (v, path) when path <> "" ->
           (match pos_float v with
            | Some value when Float.is_finite value -> Some { tk; value; path }
            | _ -> None)
       | _ -> None)
  | _ -> None

(* every --[flag] value parsed by parse_position; at least one, no ticker twice *)
let positions_of fl flag shape =
  let ps = List.filter_map (fun (k, s) ->
    if k <> flag then None
    else match parse_position s with
      | Some p -> Some p
      | None -> bad_arg (Printf.sprintf "malformed --%s %S; expected %s" flag s shape)) fl in
  if ps = [] then bad_usage ();
  List.iteri (fun i p ->
    if List.exists (fun q -> q.tk = p.tk) (List.filteri (fun j _ -> j < i) ps) then
      bad_arg (Printf.sprintf "ticker %s given in more than one --%s" p.tk flag)) ps;
  ps

let () =
  match Array.to_list Sys.argv with
  | _ :: "screen" :: rest ->
      let fl = flags ["chain"; "history"; "ticker"; "max-ask"; "min-oi"; "max-spread";
                      "min-days"; "max-days"] rest in
      screen_cmd
        ~chain_path:(get fl "chain" str_opt None)
        ~history_path:(get fl "history" str_opt None)
        ~ticker:(get fl "ticker" str_opt None)
        ~max_ask:(get fl "max-ask" pos_float None)
        ~min_oi:(get fl "min-oi" float_of_string_opt (Some 100.0))
        ~max_spread:(get fl "max-spread" pos_float (Some 0.25))
        ~min_days:(get fl "min-days" int_of_string_opt (Some 30))
        ~max_days:(get fl "max-days" int_of_string_opt (Some 240))
  | _ :: "value" :: rest ->
      let fl = flags ["chain"; "ticker"; "expiry"; "strike"; "kind"; "at"; "on"; "rate"] rest in
      value_cmd
        ~chain_path:(get fl "chain" str_opt None)
        ~ticker:(get fl "ticker" str_opt None)
        ~expiry:(get fl "expiry" parse_iso None)
        ~strike:(get fl "strike" pos_float None)
        ~kind:(get fl "kind" kind_opt None)
        ~at:(get fl "at" pos_float None)
        ~on:(get fl "on" parse_iso None)
        ~rate:(get fl "rate" float_of_string_opt (Some 0.04))
  | _ :: "drawdown" :: rest ->
      let fl = flags ["history"; "ticker"] rest in
      if List.length fl <> 2 then bad_usage ();
      drawdown_cmd
        ~history_path:(get fl "history" str_opt None)
        ~ticker:(get fl "ticker" str_opt None)
  | _ :: "corr" :: rest ->
      let fl = flags ["history"; "ticker"] rest in
      let all k = List.filter_map (fun (k', v) -> if k' = k && v <> "" then Some v else None) fl in
      (match all "history", all "ticker" with
       | [a_path; b_path], [a; b] when List.length fl = 4 -> corr_cmd ~a_path ~a ~b_path ~b
       | _ -> bad_usage ())
  | _ :: "facts" :: rest ->
      let fl = flags ["facts"; "ticker"; "years"] rest in
      facts_cmd
        ~path:(get fl "facts" str_opt None)
        ~ticker:(get fl "ticker" str_opt None)
        ~years:(get fl "years" pos_int (Some 3))
  | _ :: "book" :: rest ->
      let fl = flags ["position"; "cash"; "tolerance"; "corr-years"] rest in
      once fl ["cash"; "tolerance"; "corr-years"];
      let in_range lo hi s = match float_of_string_opt s with
        | Some f when f >= lo && f <= hi -> Some f | _ -> None in
      let positions = positions_of fl "position" "TICKER=VALUE:FILE with VALUE > 0" in
      book_cmd ~positions
        ~cash:(get fl "cash" (in_range 0.0 Float.max_float) (Some 0.0))
        ~tolerance:(Option.map (fun s -> match float_of_string_opt s with
                      | Some f when f > 0.0 && f <= 1.0 -> f
                      | Some f when f <= 0.0 ->
                          bad_arg (Printf.sprintf "--tolerance %S: give a fall above 0 and at most 1 \
                                                   (0.20 = 20%%); a goal that can bear no loss needs no \
                                                   replay, since anything but cash breaches it" s)
                      | _ -> bad_arg (Printf.sprintf "--tolerance %S: give a fall above 0 and at most 1 \
                                                       (0.20 = 20%%)" s))
                      (List.assoc_opt "tolerance" fl))
        ~corr_years:(get fl "corr-years" pos_int (Some 10))
  | _ :: "income" :: rest ->
      let fl = flags ["holding"; "other"; "need"; "floor"] rest in
      once fl ["need"; "floor"];
      let holdings = positions_of fl "holding" "TICKER=SHARES:FACTSFILE with SHARES > 0" in
      let others = List.filter_map (fun (k, s) ->
        if k <> "other" then None
        else match cut '=' s with
          | Some (name, v) when name <> "" ->
              (match pos_float v with
               | Some a when Float.is_finite a -> Some (name, a)
               | _ -> bad_arg (Printf.sprintf "malformed --other %S; expected NAME=AMOUNT with AMOUNT > 0" s))
          | _ -> bad_arg (Printf.sprintf "malformed --other %S; expected NAME=AMOUNT with AMOUNT > 0" s)) fl in
      let names = List.map (fun h -> h.tk) holdings @ List.map fst others in
      List.iteri (fun i t ->
        if List.mem t (List.filteri (fun j _ -> j < i) names) then
          bad_arg (Printf.sprintf "%s given more than once" t)) names;
      income_cmd ~holdings ~others
        ~need:(get fl "need" pos_float None)
        ~floor:(Option.map (fun s -> match pos_float s with Some f -> f | None -> bad_usage ())
                  (List.assoc_opt "floor" fl))
  | _ -> bad_usage ()
