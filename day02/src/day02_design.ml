open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
include Advent_of_fpga_kernel.Design.Include
open Signal

let clock_freq = Clock_freq.Clock_25mhz

let design_config : Design_config.t =
  { clock_freq; ulx3s_extra_synth_args = [ "-noflatten" ]; uart_fifo_depth = 1024 }
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

  let list_init_range_inclusive ~lo ~hi ~f =
    List.init (hi - lo + 1) ~f:(fun x -> f (x + lo))
  ;;

  let create _scope ({ clock; clear; id_bcd } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let invalid_id ~is_part2 =
      list_init_range_inclusive ~lo:2 ~hi:max_num_digits ~f:(fun length ->
        let l =
          list_init_range_inclusive ~lo:1 ~hi:(length - 1) ~f:(fun div ->
            (* TODO: this is kind of spaghetti but it does work, probably can be cleaned up though *)
            let divides_evenly = length % div = 0 in
            let is_divided_in_half = length % 2 = 0 && div = length / 2 in
            if divides_evenly && (is_divided_in_half || is_part2)
            then (
              let matches_length = bcd_is_length ~n:length id_bcd.value in
              let split =
                id_bcd.value
                |> sel_bottom ~width:(4 * length)
                |> split_lsb ~exact:true ~part_width:(4 * div)
              in
              let first, rest = List.split_n split 1 in
              let first = List.hd_exn first in
              (* Check all of the split segments are equivalent *)
              let split_all_equal =
                List.map rest ~f:(fun x -> x ==: first)
                |> tree ~arity:4 ~f:(reduce ~f:( &: ))
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
    { invalid_id_for_part1_bcd = invalid_id ~is_part2:false
    ; invalid_id_for_part2_bcd = invalid_id ~is_part2:true
    }
    |> O.Of_signal.pipeline ~n:1 spec
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
                       (Bcd_utils.is_ascii_number byte_in.value)
                       [ (* Shift in the new byte *)
                         current_count
                         <-- drop_top ~width:4 current_count.value
                             @: Bcd_utils.ascii_to_bcd byte_in.value
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
                       (Bcd_utils.is_ascii_number byte_in.value)
                       [ (* Shift in the new byte *)
                         upper_bound
                         <-- drop_top ~width:4 upper_bound.value
                             @: Bcd_utils.ascii_to_bcd byte_in.value
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
    Bcd_utils.bcd_to_binary ~clock ~clear invalid_id_for_part1_bcd
  in
  let%hw part1_accumulator =
    reg_fb spec ~width:60 ~enable:part1_id_is_invalid_binary.valid ~f:(fun x ->
      x +: uresize ~width:60 part1_id_is_invalid_binary.value)
  in
  let%hw.With_valid.Of_signal part2_id_is_invalid_binary =
    Bcd_utils.bcd_to_binary ~clock ~clear invalid_id_for_part2_bcd
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
