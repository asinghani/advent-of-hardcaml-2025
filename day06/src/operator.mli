open! Core
open! Hardcaml

module Cases : sig
  type t =
    | Mul
    | Add
  [@@deriving sexp_of]
end

include Hardcaml.Enum.S_enum with module Cases := Cases

val of_byte : Signal.t -> (Signal.t, Signal.t t) With_valid.t2
val to_op : Signal.t t -> Signal.t -> Signal.t -> Signal.t
val is_mul : Signal.t t -> Signal.t
val is_add : Signal.t t -> Signal.t

include functor With_valid.Wrap.Include.F
