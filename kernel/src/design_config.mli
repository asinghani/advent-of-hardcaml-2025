(** Config options for the board wrapper and synthesis script *)
open! Core

type t =
  { clock_freq : Clock_freq.t
  ; uart_fifo_depth : int
  ; ulx3s_extra_synth_args : string list
  }
[@@deriving sexp]

val default : t
