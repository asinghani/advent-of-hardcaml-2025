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

open Day06_utils

module States = struct
  type t =
    | Shift_input_value
    | Write_value
    | Flush_pipeline
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(* Compare a signal with a char *)
let ( ==:& ) a b = a ==:. Char.to_int b

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
  let%hw end_of_input = uart_rx_control.valid &: (uart_rx_control.value ==:. 1) in
  let%hw.Operator.With_valid.Of_signal operator_in =
    byte_in |> With_valid.and_then (module Signal) ~f:Operator.of_byte
  in
  let%hw.With_valid.Of_signal bcd_in =
    byte_in |> With_valid.and_then (module Signal) ~f:Bcd_utils.ascii_to_bcd_with_valid
  in
  let%hw space_in = byte_in.valid &: (byte_in.value ==:& ' ') in
  let%hw newline_in = byte_in.valid &: (byte_in.value ==:& '\n') in
  let open Always in
  let%hw.State_machine sm = State_machine.create (module States) spec in
  let%hw_var col_idx = Variable.reg spec ~width:col_bits in
  let%hw_var row_idx = Variable.reg spec ~width:row_bits in
  let%hw.Bcd_number.Of_always bcd = Bcd_number.Of_always.reg spec in
  let%hw_var write_en = Variable.wire ~default:gnd () in
  let%hw_var uart_rx_ready = Variable.wire ~default:gnd () in
  let%hw.Column_entry.Of_signal column = Column_entry.Of_signal.wires () in
  let%hw.Column_entry.Of_signal column_write =
    Column_entry.insert
      column
      ~idx:row_idx.value
      ~entry:{ With_valid.valid = vdd; value = Bcd_number.Of_always.value bcd }
  in
  Column_entry.Of_signal.assign
    column
    (Ram.create
       ~collision_mode:Read_before_write
       ~size:max_num_cols
       ~write_ports:
         [| { write_clock = clock
            ; write_address = col_idx.value
            ; write_enable = write_en.value
            ; write_data = column_write |> Column_entry.Of_signal.pack
            }
         |]
       ~read_ports:
         [| { read_clock = clock; read_address = col_idx.value; read_enable = vdd } |]
       ()
     |> (Fn.flip Array.get) 0
     |> Column_entry.Of_signal.unpack);
  (* This state-machine handles the parsing and buffering inputs into RAM
     (col-by-col), the actual computations happen in
     [Evaluate_operation_part{1,2}] modules. *)
  compile
    [ sm.switch
        [ ( Shift_input_value
          , [ uart_rx_ready <-- vdd
            ; when_
                bcd_in.valid
                [ Bcd_number.Of_always.assign
                    bcd
                    (Bcd_number.shift_in (Bcd_number.Of_always.value bcd) bcd_in.value)
                ]
            ; when_ operator_in.valid [ incr col_idx ]
            ; if_
                (space_in
                 |: newline_in
                 &: Bcd_number.(Of_always.value bcd |> Of_signal.pack |> any_bit_set))
                [ sm.set_next Write_value ]
              @@ elif newline_in [ incr row_idx; col_idx <--. 0 ]
              @@ else_ []
            ; when_ end_of_input [ sm.set_next Done ]
            ] )
        ; ( Write_value
          , [ write_en <-- vdd
            ; if_ (reg spec newline_in) [ incr row_idx; col_idx <--. 0 ]
              @@ else_ [ incr col_idx ]
            ; sm.set_next Shift_input_value
            ; Bcd_number.(Of_always.assign bcd (zero ()))
            ] )
        ; ( Flush_pipeline
          , [ Fsm_utils.after_n_clocks ~clock ~clear ~n:30 [ sm.set_next Done ] ] )
        ; Done, []
        ]
    ];
  let done_ = sm.is Done in
  let part1_accumulator =
    let%tydi { result = { valid; value } } =
      Evaluate_operation_part1.hierarchical
        scope
        { clock; clear; column; operator = operator_in }
    in
    reg_fb spec ~width:60 ~enable:valid ~f:(fun x -> x +: uresize ~width:60 value)
  in
  let%tydi { uart_tx } =
    Print_decimal_outputs.hierarchical
      scope
      { clock; clear; part1 = part1_accumulator; part2 = zero 60; done_; uart_tx_ready }
  in
  { board_leds = uextend ~width:8 done_; uart_tx; uart_rx_ready = uart_rx_ready.value }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
