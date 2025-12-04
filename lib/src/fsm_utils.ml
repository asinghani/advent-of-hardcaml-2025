open! Core
open! Hardcaml
open! Signal

let after_n_clocks ~clock ~clear ~n logic =
  let spec = Reg_spec.create ~clock ~clear () in
  let open Always in
  let counter = Variable.reg ~width:(num_bits_to_represent n) spec in
  proc
    [ counter <-- counter.value +:. 1
    ; when_ (counter.value ==:. n - 1) [ counter <--. 0; proc logic ]
    ]
;;
