(** Some shared types to help with modularization *)
open! Core

open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils

val max_num_cols : int
val max_num_digits : int
val max_num_rows : int
val result_bits : int
val col_bits : int
val row_bits : int

module Bcd_number : Bcd.S

(* Entry in RAM representing a single column of the input *)
module Column_entry : sig
  type 'a t = { numbers : 'a Bcd_number.With_valid.t list } [@@deriving hardcaml]

  val insert
    :  Signal.t t
    -> idx:Signal.t
    -> entry:Signal.t Bcd_number.With_valid.t
    -> Signal.t t
end
