(** Top level for the ULX3S board, sets up the clock and UART and maps pins to match the
    names in the board constraints *)

open! Core
open! Hardcaml
open! Advent_of_fpga_kernel

module Make (Design : Design.S) : sig
  (** ULX3S inputs, names matched to [constraints.lpf] *)
  module I : sig
    type 'a t =
      { clock25 : 'a
      ; ftdi_txd : 'a
      ; ftdi_ndtr : 'a
      ; btn : 'a
      }
    [@@deriving hardcaml]
  end

  (** ULX3S outputs, names matched to [constraints.lpf] *)
  module O : sig
    type 'a t =
      { led : 'a
      ; ftdi_rxd : 'a
      }
    [@@deriving hardcaml]
  end

  val create : Scope.t -> Interface.Create_fn(I)(O).t
end
