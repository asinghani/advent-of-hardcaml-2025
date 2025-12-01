open! Core

type t =
  { clock_freq : Clock_freq.t
  ; uart_fifo_depth : int
  ; ulx3s_extra_synth_args : string list
  }
[@@deriving sexp]

let default =
  { clock_freq = Clock_25mhz; uart_fifo_depth = 64; ulx3s_extra_synth_args = [] }
;;
