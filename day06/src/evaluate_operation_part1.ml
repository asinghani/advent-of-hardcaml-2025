open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
open Signal
open Day06_utils

module Evaluation_result_with_valid = With_valid.Vector (struct
    let width = result_bits
  end)

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; column : 'a Column_entry.t
    ; operator : 'a Operator.With_valid.t
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { result : 'a Evaluation_result_with_valid.t } [@@deriving hardcaml]
end

let tree2 ~f =
  tree ~arity:2 ~f:(function
    | [ a; b ] -> f a b
    | _ -> failwith "unreachable")
;;

let create
      _scope
      ({ clock; clear; column; operator = { value = operator; valid } } : _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let identity_bcd =
    (* Identity element, for unused rows *)
    Bcd_number.(Of_signal.mux2 (Operator.is_mul operator) (one ()) (zero ()))
  in
  let result =
    column.numbers
    |> List.map
         ~f:
           (Bcd_number.With_valid.value_with_default
              (module Signal)
              ~default:identity_bcd)
    |> List.map ~f:(fun value -> { With_valid.value; valid })
    |> List.map ~f:(Bcd_number.to_binary ~clock ~clear)
    |> tree2
       (* This is slightly sketchy since it relies on (but does not formally
            codify) the fact that to_binary is a fixed-latency operation *)
         ~f:(fun a b ->
           With_valid.map_value2
             (module Signal)
             a
             b
             ~f:(fun a b -> Operator.to_op operator a b)
           |> With_valid.map ~f:(reg spec))
    |> With_valid.map_value ~f:(sel_bottom ~width:result_bits)
  in
  { result }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~name:"do_part1" ~scope create i
;;
