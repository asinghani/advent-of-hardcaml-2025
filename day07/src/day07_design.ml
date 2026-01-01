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

(* Compare a signal with a char *)
let ( ==:& ) a b = a ==:. Char.to_int b

module Insert_line_padding = Insert_line_padding.Make (struct
    let padding_char = '.'
  end)

module Circular_buffer =
  Circular_buffer.Make
    (struct
      let delay_bits = 12
    end)
    ((val Types.scalar 48))

let create
  scope
  ({ clock; clear; uart_rx_data; uart_rx_control; uart_rx_overflow; uart_tx_ready } :
    _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let end_of_input = uart_rx_control.valid &: (uart_rx_control.value ==:. 1) in
  let%tydi { byte_out = byte_in
           ; end_of_line
           ; line_length_without_padding
           ; ready_up = uart_rx_ready
           }
    =
    Insert_line_padding.hierarchical scope { clock; clear; byte_in = uart_rx_data }
  in
  let make_window (input : _ With_valid.t) =
    Array.init 3 ~f:Fn.id
    |> Array.folding_map ~init:input.value ~f:(fun last _ ->
      let x = reg spec ~enable:input.valid last in
      x, x)
    |> Array.rev
  in
  let%hw_array window = make_window byte_in in
  let%hw start_of_line = reg spec ~enable:byte_in.valid end_of_line in
  let%hw column_idx =
    reg_fb spec ~width:12 ~enable:byte_in.valid ~f:(fun x ->
      mux2 start_of_line (zero 12) (x +:. 1))
  in
  let%hw row_idx = counter spec ~width:12 ~enable:(byte_in.valid &: start_of_line) in
  let%hw is_last_row =
    Unsigned.(row_idx ==: line_length_without_padding.value -:. 1)
    &: line_length_without_padding.valid
  in
  let%hw window_valid = byte_in.valid &: (column_idx >=:. 2) in
  let%hw counter_update = wire 48 in
  let%hw_array counter_shreg =
    let%tydi { data_out = counter_delayed } =
      Circular_buffer.hierarchical
        scope
        { clock
        ; clear
        ; data_in = counter_update
        ; shift = window_valid
        ; delay = line_length_without_padding.value -:. 2
        }
    in
    make_window { valid = window_valid; value = counter_delayed }
  in
  (counter_update
   <--
   let tmp =
     mux2 (window.(1) ==:& '^') (zero 48)
     @@ mux2 (window.(1) ==:& 'S') (one 48)
     @@ mux2 (row_idx ==:. 0) (zero 48)
     @@ counter_shreg.(1)
   in
   let tmp = mux2 (window.(0) ==:& '^') (tmp +: counter_shreg.(0)) tmp in
   let tmp = mux2 (window.(2) ==:& '^') (tmp +: counter_shreg.(2)) tmp in
   tmp);
  let%hw part1_incr =
    window_valid &: (window.(1) ==:& '^') &: (counter_shreg.(1) <>:. 0)
  in
  let%hw part1_accumulator = counter spec ~width:60 ~enable:part1_incr in
  let%hw part2_add = window_valid &: is_last_row in
  let%hw part2_accumulator =
    reg_fb spec ~width:60 ~enable:part2_add ~f:(fun x ->
      x +: uextend ~width:60 counter_update)
  in
  let%hw done_ = reg_fb spec ~width:1 ~f:(fun x -> x |: end_of_input) in
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
  { board_leds = uextend ~width:8 done_; uart_tx; uart_rx_ready }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
