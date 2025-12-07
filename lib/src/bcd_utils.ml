open! Core
open! Hardcaml
open! Signal

let ascii_to_bcd x =
  assert (width x = 8);
  (* Since ASCII 0 is 0x30, we can just select the lower bits to convert *)
  sel_bottom ~width:4 x
;;

let is_ascii_number x =
  assert (width x = 8);
  x >=:. Char.to_int '0' &: (x <=:. Char.to_int '9')
;;

let ascii_to_bcd_with_valid x =
  { With_valid.value = ascii_to_bcd x; valid = is_ascii_number x }
;;

(* Convert a BCD value to binary, with a latency of one cycle per character *)
let bcd_to_binary ~clock ~clear (x : _ With_valid.t) =
  assert (width x.value % 4 = 0);
  let spec = Reg_spec.create ~clock ~clear () in
  let mul10 a =
    (* 8a + 2a *)
    Unsigned.((a @: zero 3) +: (a @: zero 1))
  in
  let rec helper x =
    if width x = 4
    then x, 0
    else (
      let xs, x = split_in_half_lsb ~lsbs:4 x in
      let xs_as_binary, xs_latency = helper xs in
      let result = Unsigned.(mul10 xs_as_binary +: pipeline spec ~n:xs_latency x) in
      reg spec result, xs_latency + 1)
  in
  let result, latency = helper x.value in
  { With_valid.value = result; valid = pipeline spec ~n:latency x.valid }
;;
