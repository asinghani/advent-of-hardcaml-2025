(** Module for inserting padding before and after each line in an input stream *)

open! Core
open! Hardcaml

module Make (Config : sig
    val padding_char : char
  end) : sig
  module I : sig
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; byte_in : 'a With_valid.t
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { byte_out : 'a With_valid.t
      ; end_of_line : 'a
      ; line_length_without_padding : 'a With_valid.t
      ; ready_up : 'a
      }
    [@@deriving hardcaml]
  end

  val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t
end
