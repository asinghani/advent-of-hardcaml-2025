open! Core
open! Hardcaml

val ascii_to_bcd : Signal.t -> Signal.t
val is_ascii_number : Signal.t -> Signal.t
val ascii_to_bcd_with_valid : Signal.t -> Signal.t With_valid.t

val bcd_to_binary
  :  clock:Signal.t
  -> clear:Signal.t
  -> Signal.t With_valid.t
  -> Signal.t With_valid.t
