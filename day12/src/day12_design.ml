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

module Ascii_integer_parser = Ascii_integer_parser.Make (struct
    let max_num_digits = 2
  end)

module States = struct
  type t =
    | Read_first_dim
    | Read_second_dim
    | Read_counts
    | Accumulate_result
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(* Compare a signal with a char *)
let ( ==:& ) a b = a ==:. Char.to_int b

let create
      scope
      ({ clock; clear; uart_rx_data; uart_rx_control; uart_rx_overflow; uart_tx_ready } :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let%tydi { parsed_value; parsed_value_valid; separator } =
    Ascii_integer_parser.hierarchical scope { clock; clear; byte_in = uart_rx_data }
  in
  let%hw end_of_input = uart_rx_control.valid &: (uart_rx_control.value ==:. 1) in
  let mul9 a =
    (* 8a + a*)
    Unsigned.((a @: zero 3) +: a)
  in
  let open Always in
  let%hw.State_machine sm = State_machine.create (module States) spec in
  let%hw_var first_dim = Variable.reg spec ~width:7 in
  let%hw_var total_available_area = Variable.reg spec ~width:14 in
  let%hw_var upper_bound_arranged_area = Variable.reg spec ~width:16 in
  let%hw_var success_count = Variable.reg spec ~width:16 in
  let%hw_var uart_rx_ready = Variable.wire ~default:gnd () in
  compile
    [ sm.switch
        [ ( Read_first_dim
          , [ uart_rx_ready <-- vdd
            ; when_
                (parsed_value_valid &: (separator ==:& 'x'))
                [ first_dim <-- parsed_value; sm.set_next Read_second_dim ]
            ; when_ end_of_input [ sm.set_next Done ]
            ] )
        ; ( Read_second_dim
          , [ uart_rx_ready <-- vdd
            ; when_
                (parsed_value_valid &: (separator ==:& ':'))
                [ (total_available_area <-- Unsigned.(first_dim.value *: parsed_value))
                ; upper_bound_arranged_area <--. 0
                ; sm.set_next Read_counts
                ]
            ] )
        ; ( Read_counts
          , [ uart_rx_ready <-- vdd
            ; when_
                parsed_value_valid
                [ upper_bound_arranged_area
                  <-- upper_bound_arranged_area.value
                      +: (mul9 parsed_value |> uextend ~width:16)
                ; when_ (separator ==:& '\n') [ sm.set_next Accumulate_result ]
                ]
            ] )
        ; ( Accumulate_result
          , [ when_
                Unsigned.(upper_bound_arranged_area.value <=: total_available_area.value)
                [ incr success_count ]
            ; sm.set_next Read_first_dim
            ] )
        ; Done, []
        ]
    ];
  let done_ = sm.is Done in
  let%tydi { uart_tx } =
    Print_decimal_outputs.hierarchical
      scope
      { clock
      ; clear
      ; part1 = success_count.value |> uresize ~width:60
      ; part2 = zero 60
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
