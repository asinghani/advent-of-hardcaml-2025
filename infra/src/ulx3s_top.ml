open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Signal

module Make (Design : Design.S) = struct
  module I = struct
    type 'a t =
      { clock25 : 'a
      ; ftdi_txd : 'a
      ; ftdi_ndtr : 'a
      ; btn : 'a [@bits 7]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { led : 'a [@bits 8]
      ; ftdi_rxd : 'a
      }
    [@@deriving hardcaml]
  end

  module Byte_with_valid = With_valid.Vector (struct
      let width = 8
    end)

  module Uart = Uart.Make (struct
      let baud = 115200
      let clock_freq_hz = Clock_freq.to_hz Design.design_config.clock_freq
      let rx_fifo_depth = Design.design_config.uart_fifo_depth
      let tx_fifo_depth = 128
    end)

  let create scope (i : _ I.t) : _ O.t =
    let clock =
      match Design.design_config.clock_freq with
      | Clock_25mhz -> i.clock25
    in
    (* Synchronize inputs and wrap the UART for the user design to use *)
    let sync_input x = pipeline (Reg_spec.create ~clock ()) ~n:3 x in
    let btn = sync_input i.btn in
    let clear_btn = ~:(btn.:(0)) in
    let ftdi_rx = sync_input i.ftdi_txd in
    let clear = clear_btn in
    let uart_rx_ready = wire 1 in
    let%tydi { byte_out = uart_rx; fifo_overflow = uart_rx_overflow } =
      Uart.Rx.create scope { clock; clear; ready = uart_rx_ready; rx = ftdi_rx }
    in
    let uart_tx = Byte_with_valid.Of_signal.wires () in
    let%tydi { ready = uart_tx_ready; tx } =
      Uart.Tx.create scope { clock; clear; byte_in = uart_tx }
    in
    let uart_rx_ready_from_design = wire 1 in
    let%tydi { ready_up = uart_rx_ready'; data_byte; control_byte; design_reset } =
      Control_codes_protocol.hierarchical
        scope
        { clock; clear; ready_dn = uart_rx_ready_from_design; byte_in = uart_rx }
    in
    Signal.assign uart_rx_ready uart_rx_ready';
    let%tydi
        { board_leds; uart_tx = uart_tx'; uart_rx_ready = uart_rx_ready_from_design' }
      =
      Design.hierarchical
        scope
        { clock
        ; clear = clear |: design_reset
        ; uart_tx_ready
        ; uart_rx_data = data_byte
        ; uart_rx_control = control_byte
        ; uart_rx_overflow
        }
    in
    Signal.assign uart_rx_ready_from_design uart_rx_ready_from_design';
    Byte_with_valid.Of_signal.assign uart_tx uart_tx';
    { led = board_leds; ftdi_rxd = tx }
  ;;
end
