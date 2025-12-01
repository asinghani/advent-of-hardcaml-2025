(** Module type implemented by each individual day's hardware design *)

open! Core
open! Hardcaml

module Byte_with_valid = With_valid.Vector (struct
    let width = 8
  end)

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; uart_rx_data : 'a Byte_with_valid.t
    ; uart_rx_control : 'a Byte_with_valid.t
    ; uart_rx_overflow : 'a
    ; uart_tx_ready : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { board_leds : 'a [@bits 8] (** Blinkenlights! *)
    ; uart_rx_ready : 'a
    ; uart_tx : 'a Byte_with_valid.t
    }
  [@@deriving hardcaml]
end

module Include = struct
  module I = I
  module O = O
end

module type S = sig
  module I = I
  module O = O

  val design_config : Design_config.t
  val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t
end

module type Design = sig
  module I = I
  module O = O
  module Include = Include

  module type S = S
end
