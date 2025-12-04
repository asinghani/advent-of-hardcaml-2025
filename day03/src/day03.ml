(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "day03"
let parser = `Both_parts (module Day03_parser : Parser.S)
let design = `Both_parts (module Day03_design : Design.S)
