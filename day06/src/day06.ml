(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "day06"
let parser = `Both_parts (module Day06_parser : Parser.S)
let design = `Both_parts (module Day06_design : Design.S)
