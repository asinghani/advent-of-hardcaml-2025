open! Core

let%expect_test "test day07" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"test_day07.txt"
    (module Day07);
  [%expect {|
    === Output ===
    Part 1: 21
    Part 2: 40
    |}]
;;
