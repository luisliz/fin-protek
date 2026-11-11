(* ledger.ml — append-only, hash-chained decision log.
   Integrity is owned by THIS program, not by any LLM prompt.
   - append : add an entry; physically O_APPEND, never truncates/rewrites.
     A malformed entry is refused (reason on stderr, exit 2, nothing written): it needs
     at least one --key value, no empty value, type open/check/adjust/close need strategy,
     fill/review need strategy or ref, open/decision need action. Type defaults to decision.
   - verify : recompute the MD5 hash-chain; detects any edit, reorder, or deletion.
   - list / show / pending : read-only helpers.
   - thread / strategies : read-only views of entries grouped by their "strategy" field;
     a strategy is CLOSED once any of its entries has type "close". strategies adds
     PENDING when the strategy's newest open, adjust or close entry has a status starting
     with "pending" and no fill entry follows it.
   Each line is: SEQ|HASH|PAYLOAD   where HASH = MD5(prev_hash ^ RS ^ payload).
   stdlib + unix only — compiles to a single dependency-free native binary. *)

let rs = "\x1e"
let genesis = "GENESIS"

let ledger_path =
  try Sys.getenv "LEDGER_FILE" with Not_found -> "decisions/ledger.log"

(* ---- minimal JSON object builder (all values are strings) ---- *)
let json_escape s =
  let b = Buffer.create (String.length s + 8) in
  String.iter (fun c ->
    match c with
    | '"'  -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t"
    | c when Char.code c < 0x20 ->
        Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
    | c -> Buffer.add_char b c) s;
  Buffer.contents b

let json_obj fields =
  "{" ^ String.concat ","
    (List.map (fun (k,v) ->
       Printf.sprintf "\"%s\":\"%s\"" (json_escape k) (json_escape v)) fields)
  ^ "}"

(* ---- read a "key":"value" out of a payload without a full JSON parser ---- *)
let field key payload =
  let pat = "\"" ^ key ^ "\":\"" in
  let pl = String.length payload and kl = String.length pat in
  let rec find i =
    if i + kl > pl then None
    else if String.sub payload i kl = pat then Some (i + kl)
    else find (i + 1) in
  match find 0 with
  | None -> None
  | Some start ->
      let b = Buffer.create 16 in
      let rec rd j =
        if j >= pl then Some (Buffer.contents b)
        else match payload.[j] with
          | '\\' when j + 1 < pl ->
              Buffer.add_char b payload.[j];
              Buffer.add_char b payload.[j+1]; rd (j + 2)
          | '"' -> Some (Buffer.contents b)
          | c -> Buffer.add_char b c; rd (j + 1) in
      rd start

let iso_now () =
  let tm = Unix.gmtime (Unix.gettimeofday ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
    tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

let read_lines path =
  if not (Sys.file_exists path) then []
  else begin
    let ic = open_in path in
    let rec loop acc =
      match input_line ic with
      | line -> loop (line :: acc)
      | exception End_of_file -> close_in ic; List.rev acc in
    loop []
  end

(* split "SEQ|HASH|PAYLOAD" on the first two pipes; payload may contain pipes *)
let parse_line line =
  match String.index_opt line '|' with
  | None -> None
  | Some i1 ->
      let seq = String.sub line 0 i1 in
      let rest = String.sub line (i1 + 1) (String.length line - i1 - 1) in
      match String.index_opt rest '|' with
      | None -> None
      | Some i2 ->
          let hash = String.sub rest 0 i2 in
          let payload = String.sub rest (i2 + 1) (String.length rest - i2 - 1) in
          Some (seq, hash, payload)

let chain_hash prev payload = Digest.to_hex (Digest.string (prev ^ rs ^ payload))

let last_state () =
  match List.rev (read_lines ledger_path) with
  | [] -> (0, genesis)
  | last :: _ ->
      match parse_line last with
      | Some (seq, hash, _) -> (int_of_string seq, hash)
      | None -> failwith "ledger: corrupt final line"

let append payload =
  let (lastseq, lasthash) = last_state () in
  let seq = lastseq + 1 in
  let hash = chain_hash lasthash payload in
  let line = Printf.sprintf "%d|%s|%s\n" seq hash payload in
  let oc = open_out_gen [Open_append; Open_creat] 0o644 ledger_path in
  output_string oc line; close_out oc;
  Printf.printf "appended seq %d  (hash %s)\n" seq hash

let reject msg = prerr_endline ("ledger: refused, " ^ msg ^ "; nothing written"); exit 2

(* the reason an entry is malformed, or None; [fields] already carries the type *)
let invalid user_fields fields =
  let has k = List.mem_assoc k fields in
  let ty = List.assoc "type" fields in
  match List.find_opt (fun (_, v) -> v = "") fields with
  | _ when user_fields = [] -> Some "at least one --key value pair is required"
  | Some (k, _) -> Some ("--" ^ k ^ " has an empty value")
  | None ->
      if List.mem ty ["open"; "check"; "adjust"; "close"] && not (has "strategy") then
        Some ("type " ^ ty ^ " requires --strategy")
      else if List.mem ty ["fill"; "review"] && not (has "strategy" || has "ref") then
        Some ("type " ^ ty ^ " requires --strategy or --ref")
      else if List.mem ty ["open"; "decision"] && not (has "action") then
        Some ("type " ^ ty ^ " requires --action")
      else None

let verify () =
  let rec loop prev expect = function
    | [] -> Printf.printf "OK \xe2\x80\x94 %d entries, chain intact\n" (expect - 1); exit 0
    | line :: tl ->
        match parse_line line with
        | None -> Printf.printf "BROKEN: malformed line near entry %d\n" expect; exit 1
        | Some (seqs, hash, payload) ->
            let seq = int_of_string seqs in
            if seq <> expect then begin
              Printf.printf "BROKEN: sequence gap \xe2\x80\x94 expected %d, found %d (deletion/reorder)\n"
                expect seq; exit 1 end;
            let h = chain_hash prev payload in
            if h <> hash then begin
              Printf.printf "BROKEN: entry %d hash mismatch \xe2\x80\x94 it was edited or reordered\n" seq;
              exit 1 end;
            loop hash (expect + 1) tl in
  loop genesis 1 (read_lines ledger_path)

let print_entry seq p =
  let g k = match field k p with Some v -> v | None -> "-" in
  Printf.printf "%-4s %-8s %-7s %-10s %s\n"
    seq (g "type") (g "ticker") (g "action") (g "ts")

let list_entries () =
  List.iter (fun line ->
    match parse_line line with
    | Some (seq, _, p) -> print_entry seq p
    | None -> ()) (read_lines ledger_path)

let show want =
  List.iter (fun line ->
    match parse_line line with
    | Some (seq, _, p) when seq = want -> print_endline p
    | _ -> ()) (read_lines ledger_path)

(* decisions with no review entry referencing their seq *)
let pending () =
  let entries =
    List.filter_map parse_line (read_lines ledger_path) in
  let reviewed =
    List.filter_map (fun (_, _, p) ->
      match field "type" p, field "ref" p with
      | Some "review", Some r -> Some r
      | _ -> None) entries in
  List.iter (fun (seq, _, p) ->
    match field "type" p with
    | Some "decision" when not (List.mem seq reviewed) ->
        let g k = match field k p with Some v -> v | None -> "-" in
        Printf.printf "%-4s %-7s %-12s horizon=%sy  expecting: %s\n"
          seq (g "ticker") (g "action") (g "horizon_years") (g "expectation")
    | _ -> ()) entries

(* every entry of one strategy, in ledger order *)
let thread id =
  List.iter (fun line ->
    match parse_line line with
    | Some (seq, _, p) when field "strategy" p = Some id -> print_entry seq p
    | _ -> ()) (read_lines ledger_path)

(* one line per strategy, in order of first appearance *)
let strategies () =
  let tally = Hashtbl.create 16 and order = ref [] in
  List.iter (fun line ->
    match parse_line line with
    | Some (_, _, p) -> (
        match field "strategy" p with
        | None -> ()
        | Some id ->
            let ty = match field "type" p with Some t -> t | None -> "-" in
            let (n, _, closed, pending) = match Hashtbl.find_opt tally id with
              | Some x -> x
              | None -> order := id :: !order; (0, ty, false, false) in
            (* pending: the newest open/adjust/close has a status starting "pending" and no
               fill came after it *)
            let pending =
              if List.mem ty ["open"; "adjust"; "close"] then
                (match field "status" p with
                 | Some s -> String.length s >= 7 && String.sub s 0 7 = "pending"
                 | None -> false)
              else if ty = "fill" then false
              else pending in
            Hashtbl.replace tally id (n + 1, ty, closed || ty = "close", pending))
    | None -> ()) (read_lines ledger_path);
  List.iter (fun id ->
    let (n, last, closed, pending) = Hashtbl.find tally id in
    Printf.printf "%-20s %3d entries  last %-8s %s%s\n"
      id n last (if closed then "CLOSED" else "OPEN") (if pending then " PENDING" else ""))
    (List.rev !order)

let () =
  match Array.to_list Sys.argv with
  | _ :: "append" :: rest ->
      let rec pairs acc = function
        | [] -> List.rev acc
        | k :: v :: tl when String.length k > 2 && String.sub k 0 2 = "--" ->
            pairs ((String.sub k 2 (String.length k - 2), v) :: acc) tl
        | k :: _ -> reject ("malformed argument near " ^ k) in
      let user_fields = pairs [] rest in
      let fields = if List.mem_assoc "type" user_fields then user_fields
                   else ("type", "decision") :: user_fields in
      (match invalid user_fields fields with
       | Some msg -> reject msg
       | None -> append (json_obj (fields @ [("ts", iso_now ())])))
  | _ :: "verify" :: _ -> verify ()
  | _ :: "list" :: _ -> list_entries ()
  | _ :: "show" :: s :: _ -> show s
  | _ :: "pending" :: _ -> pending ()
  | _ :: "thread" :: id :: _ -> thread id
  | _ :: "strategies" :: _ -> strategies ()
  | _ ->
      prerr_endline
        "usage: ledger {append --type decision|review --key val ... | verify | list | show SEQ | pending\n\
         \ | thread STRATEGY | strategies}\n\
         append needs one non-empty --key value at least; open/check/adjust/close need --strategy,\n\
         fill/review need --strategy or --ref, open/decision (the default type) need --action.";
      exit 2
