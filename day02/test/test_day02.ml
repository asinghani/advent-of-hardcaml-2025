open! Core

let%expect_test "test day02" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:1000
    ~input_filename:"test_day02.txt"
    (module Day02);
  [%expect
    {|
    === Output ===
    Part 1: 1227775554
    Part 2: 4174379265
    |}]
;;
