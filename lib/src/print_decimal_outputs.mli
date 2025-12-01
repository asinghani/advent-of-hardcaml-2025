(** Module for printing numeric (integer) solutions in ASCII-encoded decimal *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; part1 : 'a
    ; part2 : 'a
    ; done_ : 'a
    ; uart_tx_ready : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { uart_tx : 'a With_valid.t } [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t
