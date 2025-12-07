(** Utility functions for input parsing *)

open! Advent_of_fpga_kernel

val all_ints_unsigned : string -> int list
val all_ints_signed : string -> int list

(** Directly convert the input into data bytes, optionally enforcing a newline
    and/or an end-of-input control code. *)
val raw_ascii_bytes
  :  ?end_with_newline:bool
  -> ?end_with_control_code:char option
  -> string
  -> Parser_intf.Symbol.t list
