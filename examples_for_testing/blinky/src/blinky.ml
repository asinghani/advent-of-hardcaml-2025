open! Core
open! Hardcaml
open! Advent_of_fpga_kernel

(* Dummy parser since blinky design doesn't need to parse anything *)
module Dummy_parser = struct
  let parse _ = []
end

module Blinky = struct
  include Advent_of_fpga_kernel.Design.Include
  open Signal

  let clock_freq = Clock_freq.Clock_25mhz
  let design_config = { Design_config.default with clock_freq }

  let hierarchical
    _scope
    ({ clock; clear; uart_rx_data; uart_rx_control = _; uart_rx_overflow; uart_tx_ready } :
      _ I.t)
    : _ O.t
    =
    let spec = Reg_spec.create ~clock ~clear () in
    let clock_freq_hz = Clock_freq.to_hz clock_freq in
    (* Toggle the LED every 1/2 second *)
    let count_to = clock_freq_hz / 2 in
    let counter =
      reg_fb spec ~width:(num_bits_to_represent count_to) ~f:(fun x ->
        mux2 (x ==:. count_to - 1) (zero (width x)) (x +:. 1))
    in
    let blinky =
      reg_fb spec ~width:1 ~enable:(counter ==:. count_to - 1) ~f:(fun x -> ~:x)
    in
    { board_leds = uart_rx_overflow @: blinky |> uextend ~width:O.port_widths.board_leds
    ; uart_tx = (* Loopback the UART for testing *)
                uart_rx_data
    ; uart_rx_ready = uart_tx_ready
    }
  ;;
end

let identifier = "blinky"
let parser = `Both_parts (module Dummy_parser : Parser.S)
let design = `Both_parts (module Blinky : Design.S)
