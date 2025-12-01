(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "accumulator"
let parser = `Both_parts (module Accumulator_parser : Parser.S)
let design = `Both_parts (module Accumulator_design : Design.S)
