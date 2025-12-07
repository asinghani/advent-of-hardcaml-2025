open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
open Signal
open Day06_utils

module Evaluation_result_with_valid = With_valid.Vector (struct
    let width = result_bits
  end)

module Bcd_transposed = Bcd.Make (struct
    let num_digits = max_num_rows
  end)

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; column : 'a Column_entry.t
    ; operator : 'a Operator.With_valid.t
    ; operator_offset : 'a [@bits char_idx_bits]
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

let offset_bits = address_bits_for max_num_digits

let create
      scope
      ({ clock; clear; column; operator = { value = operator; valid }; operator_offset } :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let identity_bcd =
    (* Identity element, for unused rows *)
    Bcd_number.(Of_signal.mux2 (Operator.is_mul operator) (one ()) (zero ()))
  in
  let%hw_list.Bcd_number.With_valid.Of_signal numbers_aligned =
    List.map2_exn column.numbers column.offsets ~f:(fun num offs ->
      let%hw num_digits = Bcd_number.num_digits num.value in
      let%hw padding_msbs = Unsigned.(offs -: operator_offset) in
      let%hw padding_lsbs =
        Unsigned.(
          of_unsigned_int ~width:(offset_bits + 1) max_num_digits
          -: (num_digits +: padding_msbs))
        |> sel_bottom ~width:offset_bits
      in
      Bcd_number.With_valid.Of_signal.mux
        padding_lsbs
        (List.init max_num_digits ~f:(fun i ->
           let digits =
             List.take
               (List.init i ~f:(fun _ -> zero 4) @ num.value.digits)
               max_num_digits
           in
           { With_valid.valid = num.valid; value = { Bcd_number.digits } })))
  in
  let result =
    numbers_aligned
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
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
