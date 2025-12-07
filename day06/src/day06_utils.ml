open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
open Signal

let max_num_cols = 1024
let max_num_digits = (* Maximum digits in each column *) 4
let max_num_rows = 4
let result_bits = 48
let col_bits = address_bits_for max_num_cols
let row_bits = address_bits_for max_num_rows

module Bcd_number = Bcd.Make (struct
    let num_digits = max_num_digits
  end)

(* Entry in RAM representing a single column of the input *)
module Column_entry = struct
  type 'a t = { numbers : 'a Bcd_number.With_valid.t list [@length max_num_rows] }
  [@@deriving hardcaml]

  let insert t ~idx ~entry =
    { numbers =
        List.mapi t.numbers ~f:(fun i x ->
          Bcd_number.With_valid.Of_signal.(
            (* Zero out "future" rows, since they may or may not ever be used  *)
            mux2 (idx <:. i) (zero ()) @@ mux2 (idx ==:. i) entry @@ x))
    }
  ;;
end
