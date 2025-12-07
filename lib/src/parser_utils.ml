open! Core
open! Advent_of_fpga_kernel

let all_ints_unsigned s =
  let re = Re.Perl.compile_pat "\\d+" in
  Re.matches re s |> List.map ~f:Int.of_string
;;

let all_ints_signed s =
  let re = Re.Perl.compile_pat "-?\\d+" in
  Re.matches re s |> List.map ~f:Int.of_string
;;

let raw_ascii_bytes ?(end_with_newline = false) ?(end_with_control_code = None) s =
  let open Parser.Symbol in
  let data = s |> String.strip |> String.to_list |> List.map ~f:(fun x -> Data_byte x) in
  (* Ensure we have a newline at the end for consistency *)
  [ data
  ; (if end_with_newline then [ Data_byte '\n' ] else [])
  ; (match end_with_control_code with
     | None -> []
     | Some c -> [ Control_byte c ])
  ]
  |> List.concat
;;

let%expect_test "test parsing ints" =
  print_s [%message "" ~_:("1 abc -2 -312 hello400" |> all_ints_unsigned : int list)];
  [%expect {| (1 2 312 400) |}];
  print_s [%message "" ~_:("1 abc -2 -312 hello400" |> all_ints_signed : int list)];
  [%expect {| (1 -2 -312 400) |}]
;;
