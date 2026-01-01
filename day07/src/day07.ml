(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "day07"
let parser = `Both_parts (module Day07_parser : Parser.S)
let design = `Both_parts (module Day07_design : Design.S)
