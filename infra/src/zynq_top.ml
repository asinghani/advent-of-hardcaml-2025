open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Signal

module Write_registers = struct
  type 'a t =
    { data_byte_value : 'a [@bits 8]
    ; data_byte_valid : 'a
    ; control_byte_value : 'a [@bits 8]
    ; control_byte_valid : 'a
    ; design_reset : 'a
    ; output_byte_read : 'a
    }
  [@@deriving hardcaml]

  let () = assert (sum_of_port_widths <= 32)
end

module Read_registers = struct
  type 'a t =
    { output_byte_value : 'a [@bits 8]
    ; output_byte_valid : 'a
    ; data_byte_ready : 'a
    ; board_leds : 'a [@bits 8]
    }
  [@@deriving hardcaml]

  let () = assert (sum_of_port_widths <= 32)
end

module Make (Design : Design.S) = struct
  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; write_registers : 'a [@bits Write_registers.sum_of_port_widths]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { read_registers : 'a [@bits Read_registers.sum_of_port_widths] }
    [@@deriving hardcaml]
  end

  module Byte_with_valid = With_valid.Vector (struct
      let width = 8
    end)

  let create scope ({ clock; clear; write_registers } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let%tydi
        { data_byte_value
        ; data_byte_valid
        ; control_byte_value
        ; control_byte_valid
        ; design_reset
        ; output_byte_read
        }
      =
      write_registers
      (* Clock domain cross the write registers *)
      |> pipeline spec ~n:3
      |> Write_registers.Of_signal.unpack
    in
    let rising_edge x =
      (* TODO: add a proper valid signal to the registers *)
      x &: ~:(reg spec x)
    in
    let clear = clear |: design_reset in
    let%tydi { board_leds; uart_tx = data_byte_out; uart_rx_ready = data_byte_ready } =
      Design.hierarchical
        scope
        { clock
        ; clear
        ; uart_tx_ready = vdd
        ; uart_rx_data = { value = data_byte_value; valid = rising_edge data_byte_valid }
        ; uart_rx_control =
            { value = control_byte_value; valid = rising_edge control_byte_valid }
        ; uart_rx_overflow = gnd
        }
    in
    let%tydi output_fifo =
      Fifo.create
        ~showahead:true
        ~capacity:Design.design_config.uart_fifo_depth
        ~clock
        ~clear
        ~wr:data_byte_out.valid
        ~d:data_byte_out.value
        ~rd:(rising_edge output_byte_read)
        ()
    in
    let read_registers =
      { output_byte_value = output_fifo.q
      ; output_byte_valid = ~:(output_fifo.empty)
      ; board_leds
      ; data_byte_ready
      }
      |> Read_registers.Of_signal.pack
    in
    { read_registers }
  ;;
end
