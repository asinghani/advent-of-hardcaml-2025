(** Module for shifting a multi-byte numeric value over UART *)

open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Signal

module type S = sig
  module I : sig
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; byte_in : 'a With_valid.t
      ; enable : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = { value : 'a With_valid.t } [@@deriving hardcaml]
  end

  val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t

  module For_parser : sig
    val int_to_uart_symbols : int -> Parser.Symbol.t list
  end
end

module type Numeric_shifter = sig
  module type S = S

  module Make (Config : sig
      val width : int
      val signed : bool
    end) : S

  module U32 : S
  module S32 : S
end
