(** A very simple module for encoding both control codes and data bytes onto a single UART
    stream; control codes being used to indicate things such as "end of data" or
    separating multiple chunks of data.

    The protocol uses a designated indicator byte which is inserted before each control
    code. If the indicator byte shows up in a data stream, it is sent twice, to indicate
    that it is intended to mean the literal indicator byte instead of a control code. This
    hardware module then decodes it out into two separate streams. Only a single ready
    signal is exposed, as this module directly backpressures the upstream UART regardless
    of the current state. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; ready_dn : 'a
    ; byte_in : 'a With_valid.t
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { ready_up : 'a
    ; data_byte : 'a With_valid.t
    ; control_byte : 'a With_valid.t
    ; design_reset : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t

module For_driver : sig
  (** Function for the parser to encode a list of symbols to the protocol *)
  val encode : Advent_of_fpga_kernel.Parser.Symbol.t list -> bytes

  (** Control sequence to reset the design *)
  val reset_sequence : bytes
end
