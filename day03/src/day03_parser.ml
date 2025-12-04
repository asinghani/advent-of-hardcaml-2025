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
  (* Ensure we have a newline at the end for consistency *)
  data @ [ Data_byte '\n'; Control_byte '\x01' ]
;;
