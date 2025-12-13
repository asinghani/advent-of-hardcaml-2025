open! Core
open! Hardcaml
open! Signal

module Make (Config : sig
    val max_num_digits : int
  end) =
struct
  open Config

  let max_value = Int.pow 10 max_num_digits - 1
  let out_bits = num_bits_to_represent max_value

  module Byte_in = With_valid.Vector (struct
      let width = 8
    end)

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; byte_in : 'a Byte_in.t
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { parsed_value : 'a [@bits out_bits]
      ; parsed_value_valid : 'a
      ; separator : 'a [@bits 8]
      }
    [@@deriving hardcaml]
  end

  module States = struct
    type t =
      | Idle
      | Shift_number
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create scope ({ clock; clear; byte_in } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let input_bcd = Bcd_utils.ascii_to_bcd_with_valid byte_in.value in
    let mul10_and_add a b =
      (* 8a + 2a + b *)
      Unsigned.((a @: zero 3) +: (a @: zero 1) +: b)
    in
    let open Always in
    let%hw.State_machine sm = State_machine.create (module States) spec in
    let%hw_var value_reg = Variable.reg spec ~width:out_bits in
    let%hw_var out_valid = Variable.wire ~default:gnd () in
    compile
      [ sm.switch
          [ ( Idle
            , [ when_
                  (byte_in.valid &: input_bcd.valid)
                  [ value_reg <-- uresize ~width:out_bits input_bcd.value
                  ; sm.set_next Shift_number
                  ]
              ] )
          ; ( Shift_number
            , [ when_
                  byte_in.valid
                  [ if_
                      input_bcd.valid
                      [ value_reg
                        <-- uresize
                              ~width:out_bits
                              (mul10_and_add value_reg.value input_bcd.value)
                      ]
                    @@ else_ [ out_valid <-- vdd; sm.set_next Idle ]
                  ]
              ] )
          ]
      ];
    { parsed_value = value_reg.value
    ; parsed_value_valid = out_valid.value
    ; separator = byte_in.value
    }
  ;;

  let hierarchical ?instance scope i =
    let module Scoped = Hierarchy.In_scope (I) (O) in
    Scoped.hierarchical ?instance ~here:[%here] ~scope create i
  ;;
end
