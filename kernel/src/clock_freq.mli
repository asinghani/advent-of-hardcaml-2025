open! Core

type t = Clock_25mhz [@@deriving sexp]

val to_hz : t -> int
