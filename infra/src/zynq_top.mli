open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Signal

module Write_registers : sig
  type 'a t =
    { data_byte_value : 'a
    ; data_byte_valid : 'a
    ; control_byte_value : 'a
    ; control_byte_valid : 'a
    ; design_reset : 'a
    ; output_byte_read : 'a
    }
  [@@deriving hardcaml]
end

module Read_registers : sig
  type 'a t =
    { output_byte_value : 'a
    ; output_byte_valid : 'a
    ; data_byte_ready : 'a
    ; board_leds : 'a
    }
  [@@deriving hardcaml]
end

module Make (Design : Design.S) : sig
  module I : sig
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; write_registers : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = { read_registers : 'a } [@@deriving hardcaml]
  end

  val create : Scope.t -> Interface.Create_fn(I)(O).t
end
