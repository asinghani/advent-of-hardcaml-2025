(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "day01"
let parser = `Both_parts (module Day01_parser : Parser.S)
let design = `Both_parts (module Day01_design : Design.S)
