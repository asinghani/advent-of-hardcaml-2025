open! Core
open! Hardcaml
open! Hardcaml_test_harness
open! Advent_of_fpga_kernel

module Dut (Design : Design.S) = struct
  open Signal

  module Byte_with_valid = With_valid.Vector (struct
      let width = 8
    end)

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; uart_rx : 'a Byte_with_valid.t
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { uart_tx : 'a Byte_with_valid.t
      ; uart_rx_ready : 'a
      }
    [@@deriving hardcaml]
  end

  let create scope ({ clock; clear; uart_rx } : _ I.t) : _ O.t =
    let uart_rx_ready_from_design = wire 1 in
    let%tydi { ready_up = uart_rx_ready; data_byte; control_byte; design_reset } =
      Control_codes_protocol.hierarchical
        scope
        { clock; clear; ready_dn = uart_rx_ready_from_design; byte_in = uart_rx }
    in
    let%tydi { board_leds = _; uart_tx; uart_rx_ready = uart_rx_ready_from_design' } =
      Design.hierarchical
        scope
        { clock
        ; clear = clear |: design_reset
        ; uart_tx_ready = vdd
        ; uart_rx_data = data_byte
        ; uart_rx_control = control_byte
        ; uart_rx_overflow = gnd
        }
    in
    Signal.assign uart_rx_ready_from_design uart_rx_ready_from_design';
    { uart_tx; uart_rx_ready }
  ;;
end

(* Helper functor to handle both single and multi part designs *)
module Make_harness (Design : Design.S) (Parser : Parser.S) = struct
  module Dut = Dut (Design)
  module Harness = Cyclesim_harness.Make (Dut.I) (Dut.O)

  type t =
    { sim : Harness.Sim.t
    ; recv_buffer : char Queue.t
    }

  let cycle ?(n = 1) { sim; recv_buffer } =
    let o = Cyclesim.outputs sim in
    for _ = 1 to n do
      Cyclesim.cycle sim;
      if Bits.to_bool !(o.uart_tx.valid)
      then Queue.enqueue recv_buffer (Bits.to_char !(o.uart_tx.value))
    done
  ;;

  let dump_uart_buffer { recv_buffer; _ } =
    recv_buffer
    |> Queue.to_list
    |> List.filter ~f:(fun x ->
      (* We use 0x04 to indicate end of transmission *)
      not (Char.equal x '\x04'))
    |> String.of_char_list
    |> print_endline
  ;;

  let write_byte t byte =
    let open Bits in
    let i = Cyclesim.inputs t.sim in
    let o = Cyclesim.outputs t.sim in
    i.uart_rx.value := of_char byte;
    i.uart_rx.valid := vdd;
    while not (to_bool !(o.uart_rx_ready)) do
      cycle t
    done;
    cycle t;
    i.uart_rx.valid := gnd;
    cycle ~n:20 t
  ;;

  let run_test ?(debug = false) ?(save_waves = false) ~num_cycles ~input_filename () =
    let input = Advent_of_fpga_inputs_lib.Inputs.get_input_file input_filename in
    if debug
    then (
      print_endline "=== Sample Input ===";
      print_endline input);
    let symbols = Parser.parse input in
    let uart_bytes = Control_codes_protocol.For_driver.encode symbols |> Bytes.to_list in
    let waves_config =
      if save_waves
      then
        Waves_config.to_test_directory () |> Waves_config.as_wavefile_format ~format:Vcd
      else Waves_config.no_waves
    in
    Harness.run_advanced
      ~waves_config
      ~random_initial_state:`All
      ~create:Dut.create
      (fun sim ->
         let recv_buffer = Queue.create () in
         let t = { sim; recv_buffer } in
         let open Bits in
         let i = Cyclesim.inputs sim in
         i.uart_rx.valid := gnd;
         i.clear := vdd;
         cycle ~n:4 t;
         i.clear := gnd;
         cycle ~n:4 t;
         List.iter uart_bytes ~f:(write_byte t);
         With_return.with_return (fun return ->
           for _ = 1 to num_cycles do
             cycle t;
             match Queue.peek_back recv_buffer with
             | Some '\x04' ->
               (* End of transmission *)
               return.return ()
             | _ -> ()
           done);
         print_endline "=== Output ===";
         dump_uart_buffer t)
  ;;
end

let run_combined_exn
      ?debug
      ?save_waves
      ~num_cycles
      ~input_filename
      (module Solution : Solution.S)
  =
  let module Design =
    (val match Solution.design with
         | `Both_parts design -> design
         | `Each_part _ ->
           failwith "Error: called [run_combined_exn] with separate designs")
  in
  let module Parser =
    (val match Solution.parser with
         | `Both_parts parser -> parser
         | `Each_part _ ->
           failwith "Error: called [run_combined_exn] with separate parsers")
  in
  let module Test_harness = Make_harness (Design) (Parser) in
  Test_harness.run_test ?debug ?save_waves ~num_cycles ~input_filename ()
;;

let run_part1_exn
      ?debug
      ?save_waves
      ~num_cycles
      ~input_filename
      (module Solution : Solution.S)
  =
  let module Design =
    (val match Solution.design with
         | `Both_parts _ ->
           failwith "Error: called [run_combined_exn] with combined design"
         | `Each_part (part1, _) -> part1)
  in
  let module Parser =
    (val match Solution.parser with
         | `Both_parts parser -> parser
         | `Each_part (part1_parser, _) -> part1_parser)
  in
  let module Test_harness = Make_harness (Design) (Parser) in
  Test_harness.run_test ?debug ?save_waves ~num_cycles ~input_filename ()
;;

let run_part2_exn
      ?debug
      ?save_waves
      ~num_cycles
      ~input_filename
      (module Solution : Solution.S)
  =
  let module Design =
    (val match Solution.design with
         | `Both_parts _ ->
           failwith "Error: called [run_combined_exn] with combined design"
         | `Each_part (_, part2) -> part2)
  in
  let module Parser =
    (val match Solution.parser with
         | `Both_parts parser -> parser
         | `Each_part (_, part2_parser) -> part2_parser)
  in
  let module Test_harness = Make_harness (Design) (Parser) in
  Test_harness.run_test ?debug ?save_waves ~num_cycles ~input_filename ()
;;
