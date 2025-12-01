open! Core

let%expect_test "test accumulator" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:true
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"test_accumulator.txt"
    (module Accumulator);
  [%expect
    {|
    === Sample Input ===
    123
    7
    239
    456
    1238
    61423
    9999
    256
    65536
    15724527
    0
    7777

    === Output ===
    Part 1: 15871581
    Part 2:
    |}]
;;
