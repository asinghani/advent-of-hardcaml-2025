(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "day12"
let parser = `Both_parts (module Day12_parser : Parser.S)
let design = `Both_parts (module Day12_design : Design.S)
