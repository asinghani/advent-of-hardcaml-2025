#!/usr/bin/env python3

# A very hacky script for generating a new day's directory from a template that
# is inlined into this script

import os
import sys
from pathlib import Path

def create_project(dir_path):
    path = Path(dir_path)
    
    if path.exists():
        print(f"Error: Directory {path} already exists")
        sys.exit(1)
    
    name = path.name
    
    path.mkdir(parents=True, exist_ok=True)
    
    src_dir = path / "src"
    test_dir = path / "test"
    src_dir.mkdir(exist_ok=True)
    test_dir.mkdir(exist_ok=True)
    
    module_name = name[0].upper() + name[1:]
    
    files = {
        f"src/{name}.mli": f"include Advent_of_fpga_kernel.Solution.S\n",
        
        f"src/{name}_design.mli": f"include Advent_of_fpga_kernel.Design.S\n",
        
        f"src/{name}_design.ml": f"""open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
include Advent_of_fpga_kernel.Design.Include
open Signal

let clock_freq = Clock_freq.Clock_25mhz

let design_config =
  {{ Design_config.default with clock_freq; ulx3s_extra_synth_args = [ "-noflatten" ] }}
;;

let hierarchical
      scope
      ({{ clock; clear; uart_rx_data; uart_rx_control; uart_rx_overflow; uart_tx_ready }} :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let%tydi {{ value = {{ valid; value }} }} =
    Numeric_shifter.S32.hierarchical
      scope
      {{ clock; clear; byte_in = uart_rx_data; enable = vdd }}
  in
  let counter = reg_fb spec ~width:7 ~enable:valid ~f:(fun x -> x +:. 1) in
  let accumulator =
    reg_fb spec ~width:60 ~enable:valid ~f:(fun x -> x +: sextend ~width:(width x) value)
  in
  let done_ =
    reg_fb spec ~width:1 ~f:(fun x ->
      x |: (uart_rx_control.valid &: (uart_rx_control.value ==:. 1)))
  in
  let%tydi {{ uart_tx }} =
    Print_decimal_outputs.hierarchical
      scope
      {{ clock; clear; part1 = accumulator; part2 = zero 60; done_; uart_tx_ready }}
  in
  {{ board_leds = done_ @: counter; uart_tx; uart_rx_ready = vdd }}
;;
""",
        
        f"src/{name}_parser.mli": f"include Advent_of_fpga_kernel.Parser.S\n",
        
        f"src/{name}.ml": f"""(* Test design for UART I/O *)

open! Core
open! Advent_of_fpga_kernel

let identifier = "{name}"
let parser = `Both_parts (module {module_name}_parser : Parser.S)
let design = `Both_parts (module {module_name}_design : Design.S)
""",
        
        f"src/dune": f"""(library
 (name {name})
 (libraries advent_of_fpga_kernel advent_of_fpga_utils core hardcaml)
 (preprocess
  (pps ppx_jane ppx_hardcaml)))
""",
        
        f"src/{name}_parser.ml": f"""open! Core
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils

let parse s =
  let data =
    s
    |> Advent_of_fpga_utils.Parser_utils.all_ints_signed
    |> List.concat_map ~f:Numeric_shifter.S32.For_parser.int_to_uart_symbols
  in
  data @ [ Control_byte '\\x01' ]
;;
""",
        
        f"test/test_{name}.ml": f"""open! Core

let%expect_test "test {name}" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"test_{name}.txt"
    (module {module_name});
  [%expect
    {{|
    |}}]
;;
""",
        
        f"test/dune": f"""(library
 (name {name}_test)
 (libraries
  {name}
  advent_of_fpga_kernel
  advent_of_fpga_infra
  core
  hardcaml)
 (inline_tests)
 (preprocess
  (pps ppx_jane)))
""",
    }
    
    for filepath, content in files.items():
        full_path = path / filepath
        full_path.write_text(content)
    
    print(f"Created project structure in {path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: script.py <directory_path>")
        sys.exit(1)
    
    create_project(sys.argv[1])
