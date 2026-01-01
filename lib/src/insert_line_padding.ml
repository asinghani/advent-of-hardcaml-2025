open! Core
open! Hardcaml
open Signal

(* Compare a signal with a char *)
let ( ==:& ) a b = a ==:. Char.to_int b

module Make (Config : sig
    val padding_char : char
  end) =
struct
  open Config

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; byte_in : 'a With_valid.t [@bits 8]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { byte_out : 'a With_valid.t [@bits 8]
      ; end_of_line : 'a
      ; line_length_without_padding : 'a With_valid.t [@bits 12]
      ; ready_up : 'a
      }
    [@@deriving hardcaml]
  end

  module States = struct
    type t =
      | Prefix
      | Line
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create scope ({ clock; clear; byte_in } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let open Always in
    let%hw.State_machine sm = State_machine.create (module States) spec in
    let ready_up = Variable.wire ~default:gnd () in
    let is_padding_byte = Variable.wire ~default:gnd () in
    let line_length = Variable.reg spec ~width:12 in
    let line_length_valid = Variable.reg spec ~width:1 in
    compile
      [ sm.switch
          [ Prefix, [ is_padding_byte <-- vdd; sm.set_next Line ]
          ; ( Line
            , [ is_padding_byte <-- (byte_in.value ==:& '\n')
              ; ready_up <-- vdd
              ; when_
                  byte_in.valid
                  [ if_
                      (byte_in.value ==:& '\n')
                      [ sm.set_next Prefix; line_length_valid <-- vdd ]
                    @@ else_ [ when_ ~:(line_length_valid.value) [ incr line_length ] ]
                  ]
              ] )
          ]
      ];
    { byte_out =
        { value = mux2 is_padding_byte.value (of_char padding_char) byte_in.value
        ; valid = byte_in.valid |: sm.is Prefix
        }
    ; ready_up = ready_up.value
    ; end_of_line = byte_in.valid &: (byte_in.value ==:& '\n')
    ; line_length_without_padding =
        { value = line_length.value; valid = line_length_valid.value }
    }
  ;;

  let hierarchical scope i =
    let module Scoped = Hierarchy.In_scope (I) (O) in
    Scoped.hierarchical ~here:[%here] ~scope create i
  ;;
end
