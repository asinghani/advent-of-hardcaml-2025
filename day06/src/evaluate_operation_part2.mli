open! Core
open! Hardcaml
open Day06_utils

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; column : 'a Column_entry.t
    ; operator : 'a Operator.With_valid.t
    ; operator_offset : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { result : 'a With_valid.t } [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Interface.Create_fn(I)(O).t
