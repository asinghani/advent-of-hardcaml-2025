open! Core

let input_files =
  [%embed_file_as_string "inputs/embedded.bin"]
  |> String.split_lines
  |> List.map ~f:(fun s ->
    match String.split ~on:' ' s with
    | [ filename; b64 ] ->
      let data = Base64.decode_exn b64 in
      filename, data
    | _ -> failwith "Invalid embedded.txt")
  |> Map.of_alist_exn (module String)
;;

let get_input_file filename = Map.find_exn input_files filename

let%expect_test "test file loading" =
  print_endline (get_input_file "test_accumulator.txt");
  [%expect {|
    123
    7
    239
    456
    1238
    61423
    9999
    256
    65536
    15724527
    0
    7777
    |}]
;;
