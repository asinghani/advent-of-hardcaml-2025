(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "day02"
let parser = `Both_parts (module Day02_parser : Parser.S)
let design = `Both_parts (module Day02_design : Design.S)
