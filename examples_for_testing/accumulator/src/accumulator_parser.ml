open! Core
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils

let parse s =
  let data =
    s
    |> Advent_of_fpga_utils.Parser_utils.all_ints_signed
    |> List.concat_map ~f:Numeric_shifter.S32.For_parser.int_to_uart_symbols
  in
  data @ [ Control_byte '\x01' ]
;;
