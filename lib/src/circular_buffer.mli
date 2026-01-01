(** A circular buffer, effectively behaving like a dynamic-length shift register without
    needing a deep mux tree. *)

open! Core
open! Hardcaml

module Make
    (Config : sig
       val delay_bits : int
     end)
    (Data : Interface.S) : sig
  module I : sig
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; data_in : 'a Data.t
      ; shift : 'a
      ; delay : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = { data_out : 'a Data.t } [@@deriving hardcaml]
  end

  val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t
end
