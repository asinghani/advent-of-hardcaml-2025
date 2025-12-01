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

module States = struct
  type t =
    | Wait_for_input
    | Counting
    | End_of_movement
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create
      scope
      ({ clock; clear; uart_rx_data; uart_rx_control; uart_rx_overflow; uart_tx_ready } :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let%tydi { value = { valid = data_in_valid; value = data_in } } =
    Numeric_shifter.U32.hierarchical
      scope
      { clock; clear; byte_in = uart_rx_data; enable = vdd }
  in
  let data_in = Input_value.unpack data_in in
  let open Always in
  let sm = State_machine.create (module States) spec in
  let uart_rx_ready = Variable.wire ~default:gnd () in
  let position = Variable.reg spec ~width:7 ~clear_to:(of_unsigned_int ~width:7 50) in
  let part1_count = Variable.reg spec ~width:16 in
  let part2_count = Variable.reg spec ~width:16 in
  let current_dir = Left_or_right.Of_always.reg spec in
  let current_count = Variable.reg spec ~width:16 in
  (* A very primitive but very functional approach of just counting every
     individual tick, this trades off performance (it scales with the sum of
     the input values) for area and simplicity (this requires a pair of
     counters and very little else). *)
  compile
    [ sm.switch
        [ ( Wait_for_input
          , [ uart_rx_ready <-- vdd
            ; when_
                data_in_valid
                [ Left_or_right.Of_always.assign current_dir data_in.left_or_right
                ; current_count <-- data_in.value
                ; sm.set_next Counting
                ]
            ; when_
                (uart_rx_control.valid &: (uart_rx_control.value ==:. 1))
                [ sm.set_next Done ]
            ] )
        ; ( Counting
          , [ Left_or_right.Of_always.(
                (* Increment or decrement the position, wrapping around to stay
                   within 0-99 range. *)
                match_
                  (value current_dir)
                  [ ( Left
                    , [ decr position
                      ; when_ (position.value ==:. 0) [ position <--. 99 ]
                      ] )
                  ; ( Right
                    , [ incr position
                      ; when_ (position.value ==:. 99) [ position <--. 0 ]
                      ] )
                  ])
            ; decr current_count
            ; when_
                (position.value ==:. 0)
                [ (* For part 2, we want to track every tick where we cross zero. *)
                  incr part2_count
                ]
            ; when_ (current_count.value ==:. 1) [ sm.set_next End_of_movement ]
            ] )
        ; ( End_of_movement
          , [ when_
                (position.value ==:. 0)
                [ (* For part 1, we only want to count when we are at zero at
                     the end of a movement. *)
                  incr part1_count
                ]
            ; sm.set_next Wait_for_input
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
      ; part1 = part1_count.value |> uextend ~width:60
      ; part2 = part2_count.value |> uextend ~width:60
      ; done_
      ; uart_tx_ready
      }
  in
  { board_leds = uresize ~width:8 done_; uart_tx; uart_rx_ready = uart_rx_ready.value }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
