open! Core
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils

let parse s =
  let data =
    s
    |> String.split_lines
    |> List.map ~f:(fun line ->
      let left_or_right = Left_or_right.Cases.of_char (String.get line 0) in
      let value = Int.of_string (String.drop_prefix line 1) in
      Input_value.pack left_or_right value)
    |> List.concat_map ~f:Numeric_shifter.U32.For_parser.int_to_uart_symbols
  in
  data @ [ Control_byte '\x01' ]
;;
