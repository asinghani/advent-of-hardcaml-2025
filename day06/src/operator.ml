open! Core
open! Hardcaml
open! Signal

module Cases = struct
  type t =
    | Mul
    | Add
  [@@deriving sexp_of, compare ~localize, enumerate]
end

include Enum.Make_binary (Cases)

let of_byte s =
  assert (width s = 8);
  let is_mul = Signal.( ==: ) s (of_char '*') in
  let is_add = Signal.( ==: ) s (of_char '+') in
  { With_valid.valid = is_mul |: is_add
  ; value = Of_signal.mux2 is_mul (Of_signal.of_enum Mul) (Of_signal.of_enum Add)
  }
;;

let to_op t a b =
  let mul = Unsigned.(a *: b) in
  let add = Unsigned.(a +: b)  |> uextend ~width:(width mul) in
  Of_signal.match_ t [ (Mul, mul); (Add, add) ]
;;

let is_mul t = Of_signal.match_ t [ Mul, vdd; Add, gnd ]
let is_add t = Of_signal.match_ t [ Mul, gnd; Add, vdd ]

include functor With_valid.Wrap.Include.Make
