open! Core
open! Hardcaml

type 'a t =
  { value : 'a
  ; left_or_right : 'a Left_or_right.t
  }
[@@deriving hardcaml]

val pack : Left_or_right.Cases.t -> int -> int
val unpack : Signal.t -> Signal.t t
