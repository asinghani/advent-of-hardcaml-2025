open! Core
open! Hardcaml

val after_n_clocks
  :  clock:Signal.t
  -> clear:Signal.t
  -> n:int
  -> Always.t list
  -> Always.t
