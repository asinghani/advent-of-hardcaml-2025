open! Core

type t = Clock_25mhz [@@deriving sexp]

let to_hz = function
  | Clock_25mhz -> 25_000_000
;;
