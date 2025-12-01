open! Core

let all_ints_unsigned s =
  let re = Re.Perl.compile_pat "\\d+" in
  Re.matches re s |> List.map ~f:Int.of_string
;;

let all_ints_signed s =
  let re = Re.Perl.compile_pat "-?\\d+" in
  Re.matches re s |> List.map ~f:Int.of_string
;;

let%expect_test "test parsing ints" =
  print_s [%message "" ~_:("1 abc -2 -312 hello400" |> all_ints_unsigned : int list)];
  [%expect {| (1 2 312 400) |}];
  print_s [%message "" ~_:("1 abc -2 -312 hello400" |> all_ints_signed : int list)];
  [%expect {| (1 -2 -312 400) |}]
;;
