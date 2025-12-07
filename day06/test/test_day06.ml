open! Core

let%expect_test "test day06" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"test_day06.txt"
    (module Day06);
  [%expect
    {|
    === Output ===
    Part 1: 6988348594
    Part 2:
    |}]
;;
