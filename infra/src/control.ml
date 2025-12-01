open! Core
open! Advent_of_fpga_kernel
open! Async
open! Tiny_serial

let validate_system_config () =
  if Int.num_bits <> 63 then failwith "32-bit system not supported"
;;

let parsers =
  Solutions.solutions
  |> List.concat_map ~f:(fun (module Solution : Solution.S) ->
    match Solution.parser with
    | `Both_parts parser -> [ Solution.identifier, parser ]
    | `Each_part (pt1_parser, pt2_parser) ->
      [ Solution.identifier ^ "-pt1", pt1_parser
      ; Solution.identifier ^ "-pt2", pt2_parser
      ])
  |> List.map ~f:(fun (name, parser) ->
    let module Parser = (val parser) in
    name, Parser.parse)
;;

let main ~port ~filename ~parse =
  validate_system_config ();
  let input = Advent_of_fpga_inputs_lib.Inputs.get_input_file filename in
  let symbols = parse input in
  let uart_bytes = Control_codes_protocol.For_driver.encode symbols in
  let%bind serial = Serial.create ~baud:115200 port in
  let%bind () =
    Serial.write_bytes serial Control_codes_protocol.For_driver.reset_sequence
  in
  let%bind () = Serial.write_bytes serial uart_bytes in
  let timeout = Time_ns.Span.of_int_sec 5 in
  let rec read_string () =
    let%bind c = Serial.read_char serial in
    (* We use 0x04 to indicate end of transmission *)
    if Char.equal c '\x04'
    then return []
    else (
      let%bind cs = read_string () in
      return (c :: cs))
  in
  let%bind result =
    Async.with_timeout_exn
      timeout
      ~error:(Error.of_string "Timed out waiting for result")
      (read_string ())
  in
  result |> String.of_char_list |> print_string;
  return ()
;;

let command =
  parsers
  |> List.map
       ~f:
         (Tuple2.map_snd ~f:(fun parse ->
            Command.async
              ~summary:"Interface with the FPGA"
              (let%map_open.Command filename = anon ("filename" %: string)
               and port =
                 flag "port" (required string) ~doc:"PORT the serial port to connect to"
               in
               fun () -> main ~port ~filename ~parse)))
  |> Command.group ~summary:"Interface with the FPGA"
;;
