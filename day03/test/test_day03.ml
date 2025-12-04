open! Core

let%expect_test "test day03" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"test_day03.txt"
    (module Day03);
  [%expect
    {|
    === Output ===
    Part 1: 357
    Part 2: 3121910778619
    |}]
;;
