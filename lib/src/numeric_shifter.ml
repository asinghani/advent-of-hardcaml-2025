open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Signal
include Numeric_shifter_intf

module Make (Config : sig
    val width : int
    val signed : bool
  end) =
struct
  open Config

  let num_bytes =
    assert (width % 8 = 0);
    assert (width < Int.num_bits);
    width / 8
  ;;

  module Byte_in = With_valid.Vector (struct
      let width = 8
    end)

  module Value_out = With_valid.Vector (Config)

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; byte_in : 'a Byte_in.t
      ; enable : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { value : 'a Value_out.t } [@@deriving hardcaml]
  end

  let create scope ({ clock; clear; byte_in; enable } : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock ~clear () in
    let valid_in = enable &: byte_in.valid in
    let counter =
      reg_fb spec ~width:(num_bits_to_represent num_bytes) ~enable:valid_in ~f:(fun x ->
        mux2 (x ==:. num_bytes - 1) (zero (Signal.width x)) (x +:. 1))
    in
    let shreg =
      reg_fb spec ~width ~enable:valid_in ~f:(fun x ->
        drop_bottom ~width:8 (byte_in.value @: x))
    in
    let valid = reg spec (valid_in &: (counter ==:. num_bytes - 1)) in
    { value = { With_valid.valid; value = shreg } }
  ;;

  let hierarchical scope i =
    let module Scoped = Hierarchy.In_scope (I) (O) in
    Scoped.hierarchical ~here:[%here] ~scope create i
  ;;

  module For_parser = struct
    let int_to_uart_symbols x =
      if not signed then assert (x >= 0);
      List.init num_bytes ~f:(fun i -> Char.of_int_exn ((x lsr (i * 8)) land 0xFF))
      |> List.map ~f:(fun x -> Parser.Symbol.Data_byte x)
    ;;
  end
end

module U32 = Make (struct
    let width = 32
    let signed = false
  end)

module S32 = Make (struct
    let width = 32
    let signed = true
  end)
