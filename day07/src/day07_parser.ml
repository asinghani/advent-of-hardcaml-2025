open! Core
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils

let parse =
  Parser_utils.raw_ascii_bytes ~end_with_newline:true ~end_with_control_code:(Some '\x01')
;;
