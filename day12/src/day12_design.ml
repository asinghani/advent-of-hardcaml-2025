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

let create
      scope
      ({ clock; clear; uart_rx_data; uart_rx_control; uart_rx_overflow; uart_tx_ready } :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let%tydi { value = { valid; value } } =
    Numeric_shifter.S32.hierarchical
      scope
      { clock; clear; byte_in = uart_rx_data; enable = vdd }
  in
  let counter = reg_fb spec ~width:7 ~enable:valid ~f:(fun x -> x +:. 1) in
  let accumulator =
    reg_fb spec ~width:60 ~enable:valid ~f:(fun x -> x +: sextend ~width:(width x) value)
  in
  let done_ =
    reg_fb spec ~width:1 ~f:(fun x ->
      x |: (uart_rx_control.valid &: (uart_rx_control.value ==:. 1)))
  in
  let%tydi { uart_tx } =
    Print_decimal_outputs.hierarchical
      scope
      { clock; clear; part1 = accumulator; part2 = zero 60; done_; uart_tx_ready }
  in
  { board_leds = done_ @: counter; uart_tx; uart_rx_ready = vdd }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
