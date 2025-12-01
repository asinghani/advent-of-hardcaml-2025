open! Core
open! Hardcaml

module Cases : sig
  type t =
    | Left
    | Right
  [@@deriving sexp_of]

  val of_char : char -> t
end

include Hardcaml.Enum.S_enum with module Cases := Cases
