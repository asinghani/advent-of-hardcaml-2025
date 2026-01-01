open! Core
open! Hardcaml
open Signal

module Make
    (Config : sig
       val delay_bits : int
     end)
    (Data : Interface.S) =
struct
  open Config

  let max_delay = 1 lsl delay_bits

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; data_in : 'a Data.t
      ; shift : 'a
      ; delay : 'a [@bits delay_bits]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { data_out : 'a Data.t } [@@deriving hardcaml]
  end

  let create scope ({ clock; clear; data_in; shift; delay } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let%hw write_address = counter spec ~width:delay_bits ~enable:shift in
    let%hw read_address = write_address -: (delay -:. 1) in
    let data_out =
      Ram.create
        ~collision_mode:Write_before_read
        ~size:max_delay
        ~write_ports:
          [| { write_clock = clock
             ; write_data = Data.Of_signal.pack data_in
             ; write_enable = shift
             ; write_address
             }
          |]
        ~read_ports:[| { read_clock = clock; read_enable = shift; read_address } |]
        ()
      |> (Fn.flip Array.get) 0
      |> Data.Of_signal.unpack
    in
    { data_out }
  ;;

  let hierarchical scope i =
    let module Scoped = Hierarchy.In_scope (I) (O) in
    Scoped.hierarchical ~here:[%here] ~scope create i
  ;;
end
