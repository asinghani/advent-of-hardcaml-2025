open! Core
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils

let parse s =
  let data =
    s
    |> String.strip
    |> String.to_list
    |> List.map ~f:(fun x -> Parser.Symbol.Data_byte x)
  in
  data @ [ Control_byte '\x01' ]
;;
