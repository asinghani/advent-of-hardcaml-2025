open! Core

let%expect_test "test day01" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"test_day01.txt"
    (module Day01);
  [%expect
    {|
    === Output ===
    Part 1: 3
    Part 2: 6
    |}]
;;
