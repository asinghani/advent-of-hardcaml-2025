open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
include Advent_of_fpga_kernel.Design.Include
open Signal

let clock_freq = Clock_freq.Clock_25mhz

let design_config =
  { Design_config.default with clock_freq; ulx3s_extra_synth_args = [ "-noflatten" ] }
;;

let max_num_digits = 10
let num_bits_bcd = 4 * max_num_digits

(* Module that takes an ID as binary-coded decimal as an input and re-outputs
   it if it was detected as an invalid ID, as per the requirements of both part
   1 and part 2. *)
module Check_if_id_invalid = struct
  module Bcd_with_valid = With_valid.Vector (struct
      let width = num_bits_bcd
    end)

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; id_bcd : 'a Bcd_with_valid.t
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { invalid_id_for_part1_bcd : 'a Bcd_with_valid.t
      ; invalid_id_for_part2_bcd : 'a Bcd_with_valid.t
      }
    [@@deriving hardcaml]
  end

  (* Check that a BCD value has exactly the given number of digits, omitting
     leading zeros *)
  let bcd_is_length ~n x =
    if 4 * n = width x
    then sel_top ~width:4 x <>:. 0
    else (
      let hi, lo = split_in_half_lsb ~lsbs:(4 * n) x in
      hi ==:. 0 &: (sel_top ~width:4 lo <>:. 0))
  ;;

  let create _scope ({ clock; clear; id_bcd } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let invalid_id ~allow_any_number_of_parts =
      List.range ~start:`inclusive ~stop:`inclusive 2 max_num_digits
      |> List.map ~f:(fun length ->
        let l =
          List.range ~start:`inclusive ~stop:`inclusive 1 (length - 1)
          |> List.map ~f:(fun div ->
            (* TODO: this is kind of spaghetti but it does work, probably can be cleaned up though *)
            if
              length % div = 0
              && ((length % 2 = 0 && div = length / 2) || allow_any_number_of_parts)
            then (
              let matches_length = bcd_is_length ~n:length id_bcd.value in
              let lower_part = sel_bottom ~width:(4 * length) id_bcd.value in
              let split = split_lsb ~exact:true ~part_width:(4 * div) lower_part in
              let first, rest = List.split_n split 1 in
              let first = List.hd_exn first in
              let split_all_equal =
                List.map rest ~f:(fun x -> x ==: first) |> reduce ~f:( &: )
              in
              Some
                { With_valid.value = id_bcd.value
                ; valid = id_bcd.valid &: matches_length &: split_all_equal
                })
            else None)
          |> List.filter_opt
        in
        if List.length l = 0 then None else Some (priority_select l))
      |> List.filter_opt
      |> priority_select
    in
    { invalid_id_for_part1_bcd = invalid_id ~allow_any_number_of_parts:false
    ; invalid_id_for_part2_bcd = invalid_id ~allow_any_number_of_parts:true
    }
    |> O.Of_signal.pipeline ~n:3 spec
  ;;
end

(* Increment a BCD value, provided as a flat signal *)
let bcd_incr (x : Signal.t) : Signal.t =
  assert (width x % 4 = 0);
  let rec helper ~carry = function
    | [] -> []
    | x :: xs ->
      (* If we are incrementing the current value and it is 9, then we are going
       to need a carry *)
      (* Increment the current value if we need to (wrapping 9+1 -> zero), else
       keep the current value *)
      let incr_x = mux2 carry (mux2 (x ==:. 9) (zero 4) (x +:. 1)) x in
      let carry = carry &: (x ==:. 9) in
      incr_x :: helper xs ~carry
  in
  x |> split_lsb ~exact:true ~part_width:4 |> helper ~carry:vdd |> concat_lsb
;;

let bcd_to_binary ~clock ~clear (x : _ With_valid.t) =
  assert (width x.value % 4 = 0);
  let spec = Reg_spec.create ~clock ~clear () in
  let mul10 a =
    (* 8a + 2a *)
    Unsigned.((a @: zero 3) +: (a @: zero 1))
  in
  let rec helper x =
    if width x = 4
    then x, 0
    else (
      let xs, x = split_in_half_lsb ~lsbs:4 x in
      let xs_as_binary, xs_latency = helper xs in
      let result = Unsigned.(mul10 xs_as_binary +: pipeline spec ~n:xs_latency x) in
      reg spec result, xs_latency + 1)
  in
  let result, latency = helper x.value in
  { With_valid.value = result; valid = pipeline spec ~n:latency x.valid }
;;

let ascii_to_bcd x =
  assert (width x = 8);
  (* Since ASCII 0 is 0x30, we can just select the lower bits to convert *)
  sel_bottom ~width:4 x
;;

let is_ascii_number x =
  assert (width x = 8);
  x >=:. Char.to_int '0' &: (x <=:. Char.to_int '9')
;;

(* Compare a signal with a char *)
let ( ==:& ) a b = a ==:. Char.to_int b

module States = struct
  type t =
    | Read_lower_bound
    | Read_upper_bound
    | Iterate_over_range
    | Flush_pipeline
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create
      scope
      ({ clock
       ; clear
       ; uart_rx_data = byte_in
       ; uart_rx_control
       ; uart_rx_overflow
       ; uart_tx_ready
       } :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let end_of_input = uart_rx_control.valid &: (uart_rx_control.value ==:. 1) in
  let open Always in
  let%hw.State_machine sm = State_machine.create (module States) spec in
  let%hw_var current_count = Variable.reg spec ~width:num_bits_bcd in
  let%hw_var current_count_valid = Variable.wire ~default:gnd () in
  let%hw_var upper_bound = Variable.reg spec ~width:num_bits_bcd in
  let%hw_var last = Variable.reg spec ~width:1 in
  let%hw_var flush_counter = Variable.reg spec ~width:8 in
  let%hw_var uart_rx_ready = Variable.wire ~default:gnd () in
  compile
    [ sm.switch
        [ ( Read_lower_bound
          , [ uart_rx_ready <-- vdd
            ; when_
                byte_in.valid
                [ if_
                    (byte_in.value ==:& '-')
                    [ (* Dash separates lower and upper bound in the range *)
                      sm.set_next Read_upper_bound
                    ]
                  @@ elif
                       (is_ascii_number byte_in.value)
                       [ (* Shift in the new byte *)
                         current_count
                         <-- drop_top ~width:4 current_count.value
                             @: ascii_to_bcd byte_in.value
                       ]
                  @@ [ (* Ignore invalid byte *) ]
                ]
            ] )
        ; ( Read_upper_bound
          , [ uart_rx_ready <-- vdd
            ; when_
                byte_in.valid
                [ if_
                    (byte_in.value ==:& ',')
                    [ (* Comma separates lower bound and next range *)
                      sm.set_next Iterate_over_range
                    ]
                  @@ elif
                       (is_ascii_number byte_in.value)
                       [ (* Shift in the new byte *)
                         upper_bound
                         <-- drop_top ~width:4 upper_bound.value
                             @: ascii_to_bcd byte_in.value
                       ]
                  @@ [ (* Ignore invalid byte *) ]
                ]
            ; when_ end_of_input [ last <-- vdd; sm.set_next Iterate_over_range ]
            ] )
        ; ( Iterate_over_range
          , [ current_count_valid <-- vdd
            ; current_count <-- bcd_incr current_count.value
            ; (* Upper bound is inclusive *)
              when_
                (current_count.value ==: upper_bound.value)
                [ current_count <--. 0
                ; upper_bound <--. 0
                ; if_ last.value [ sm.set_next Flush_pipeline ]
                  @@ else_ [ sm.set_next Read_lower_bound ]
                ]
            ] )
        ; ( Flush_pipeline
          , [ incr flush_counter
              (* An overestimation of the depth of the pipeline, to flush it
                 out and make sure the result is stable. *)
            ; when_ (flush_counter.value ==:. 50) [ sm.set_next Done ]
            ] )
        ; Done, []
        ]
    ];
  let current_count =
    { With_valid.value = current_count.value; valid = current_count_valid.value }
  in
  let%tydi { invalid_id_for_part1_bcd; invalid_id_for_part2_bcd } =
    Check_if_id_invalid.create scope { clock; clear; id_bcd = current_count }
  in
  let%hw.With_valid.Of_signal part1_id_is_invalid_binary =
    bcd_to_binary ~clock ~clear invalid_id_for_part1_bcd
  in
  let%hw part1_accumulator =
    reg_fb spec ~width:60 ~enable:part1_id_is_invalid_binary.valid ~f:(fun x ->
      x +: uresize ~width:60 part1_id_is_invalid_binary.value)
  in
  let%hw.With_valid.Of_signal part2_id_is_invalid_binary =
    bcd_to_binary ~clock ~clear invalid_id_for_part2_bcd
  in
  let%hw part2_accumulator =
    reg_fb spec ~width:60 ~enable:part2_id_is_invalid_binary.valid ~f:(fun x ->
      x +: uresize ~width:60 part2_id_is_invalid_binary.value)
  in
  let done_ = sm.is Done in
  let%tydi { uart_tx } =
    Print_decimal_outputs.hierarchical
      scope
      { clock
      ; clear
      ; part1 = part1_accumulator
      ; part2 = part2_accumulator
      ; done_
      ; uart_tx_ready
      }
  in
  { board_leds = uextend ~width:8 done_; uart_tx; uart_rx_ready = uart_rx_ready.value }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
