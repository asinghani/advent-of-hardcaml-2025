(* Module for parsing integers out of an ASCII stream *)
open! Core
open! Hardcaml
open! Signal

module Make (Config : sig
    val max_num_digits : int
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
      { parsed_value : 'a
      ; parsed_value_valid : 'a
      ; separator : 'a
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Interface.Create_fn(I)(O).t
end
