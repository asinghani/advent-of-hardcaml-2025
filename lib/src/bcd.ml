open! Core
open! Hardcaml
open! Signal
include Bcd_intf

module Make (Config : sig
    val num_digits : int
  end) =
struct
  open Config

  let num_digits_bits = num_bits_to_represent num_digits

  module T = struct
    type 'a t = { digits : 'a list [@bits 4] [@length num_digits] } [@@deriving hardcaml]
  end

  include T

  let flatten t = concat_lsb t.digits

  let unflatten s =
    assert (width s = 4 * num_digits);
    let digits = split_lsb ~exact:true ~part_width:4 s in
    { digits }
  ;;

  let zero () = Of_signal.zero ()
  let one () = one (4 * num_digits) |> unflatten

  let shift_in t s =
    assert (width s = 4);
    { digits = s :: List.drop_last_exn t.digits }
  ;;

  let num_digits t =
    (* Find the highest set bit *)
    t.digits
    |> List.mapi ~f:(fun i d ->
      { With_valid.valid = any_bit_set d
      ; value = of_unsigned_int ~width:num_digits_bits (i + 1)
      })
    |> List.rev
    |> priority_select_with_default ~default:(Signal.zero num_digits_bits)
  ;;

  module With_valid = With_valid.Wrap.Make (T)

  let to_binary ~clock ~clear (x : _ With_valid.t) =
    x |> Hardcaml.With_valid.map_value ~f:flatten |> Bcd_utils.bcd_to_binary ~clock ~clear
  ;;
end
