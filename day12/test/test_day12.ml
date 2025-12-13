open! Core

let%expect_test "test day12" =
  Advent_of_fpga_infra.Test_harness.run_combined_exn
    ~debug:false
    ~save_waves:false
    ~num_cycles:100
    ~input_filename:"day12.txt"
      (* For day 12, the sample input is not representative of the real one *)
    (module Day12);
  [%expect
    {|
    |}]
;;
