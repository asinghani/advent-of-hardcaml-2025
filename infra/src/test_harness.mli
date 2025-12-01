open! Core
open! Advent_of_fpga_kernel

val run_combined_exn
  :  ?debug:bool
  -> ?save_waves:bool
  -> num_cycles:int
  -> input_filename:string
  -> (module Solution.S)
  -> unit

val run_part1_exn
  :  ?debug:bool
  -> ?save_waves:bool
  -> num_cycles:int
  -> input_filename:string
  -> (module Solution.S)
  -> unit

val run_part2_exn
  :  ?debug:bool
  -> ?save_waves:bool
  -> num_cycles:int
  -> input_filename:string
  -> (module Solution.S)
  -> unit
