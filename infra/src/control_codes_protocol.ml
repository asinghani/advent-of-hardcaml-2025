open! Core
open! Hardcaml
open! Signal

module Byte_with_valid = With_valid.Vector (struct
    let width = 8
  end)

let control_byte_bits = 7
let control_code_max = 1 lsl control_byte_bits
let control_byte_indicator = 0xEF
let control_code_reset = control_code_max + 1
let () = assert (control_byte_indicator > control_code_reset)

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; ready_dn : 'a
    ; byte_in : 'a Byte_with_valid.t
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready_up : 'a
    ; data_byte : 'a Byte_with_valid.t
    ; control_byte : 'a Byte_with_valid.t
    ; design_reset : 'a
    }
  [@@deriving hardcaml]
end

module States = struct
  type t =
    | Data
    | Maybe_control
    | Design_reset
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let reset_cycles = 10

let create scope ({ clock; clear; ready_dn; byte_in } : _ I.t) : _ O.t =
  let open Always in
  let spec = Reg_spec.create ~clock ~clear () in
  let sm = State_machine.create (module States) spec in
  let data_byte_valid = Variable.wire ~default:gnd () in
  let control_byte_valid = Variable.wire ~default:gnd () in
  let do_design_reset = Variable.wire ~default:gnd () in
  let ready_up = Variable.wire ~default:gnd () in
  let design_reset_counter =
    Variable.reg spec ~width:(num_bits_to_represent reset_cycles)
  in
  let byte_in_valid = ready_dn &: byte_in.valid in
  compile
    [ data_byte_valid <-- gnd
    ; control_byte_valid <-- gnd
    ; do_design_reset <-- gnd
    ; sm.switch
        [ ( Data
          , [ ready_up <-- ready_dn
            ; when_
                byte_in_valid
                [ if_
                    (byte_in.value ==:. control_byte_indicator)
                    [ sm.set_next Maybe_control ]
                  @@ else_ [ data_byte_valid <-- vdd ]
                ]
            ] )
        ; ( Maybe_control
          , [ ready_up <-- ready_dn
            ; when_
                byte_in_valid
                [ sm.set_next Data
                ; if_
                    (byte_in.value ==:. control_byte_indicator)
                    [ data_byte_valid <-- vdd ]
                  @@ elif
                       (byte_in.value ==:. control_code_reset)
                       [ design_reset_counter <--. reset_cycles
                       ; sm.set_next Design_reset
                       ]
                  @@ else_ [ control_byte_valid <-- vdd ]
                ]
            ] )
        ; ( Design_reset
          , [ ready_up <-- gnd
            ; do_design_reset <-- vdd
            ; decr design_reset_counter
            ; when_ (design_reset_counter.value ==:. 0) [ sm.set_next Data ]
            ] )
        ]
    ];
  { ready_up = ready_up.value
  ; data_byte = { valid = data_byte_valid.value; value = byte_in.value }
  ; control_byte = { valid = control_byte_valid.value; value = byte_in.value }
  ; design_reset = do_design_reset.value
  }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;

module For_driver = struct
  let encode (symbols : Advent_of_fpga_kernel.Parser.Symbol.t list) =
    let control_byte_indicator = Char.of_int_exn control_byte_indicator in
    let control_code_max = Char.of_int_exn control_code_max in
    List.concat_map symbols ~f:(function
      | Data_byte x -> if Char.equal x control_byte_indicator then [ x; x ] else [ x ]
      | Control_byte x ->
        assert (Char.O.(x < control_code_max));
        [ control_byte_indicator; x ])
    |> Bytes.of_char_list
  ;;

  let reset_sequence =
    [ control_byte_indicator; control_code_reset ]
    |> List.map ~f:Char.of_int_exn
    |> Bytes.of_char_list
  ;;
end
