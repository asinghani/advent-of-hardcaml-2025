open! Core
open! Hardcaml

let width = 16

type 'a t =
  { value : 'a [@bits width]
  ; left_or_right : 'a Left_or_right.t
  }
[@@deriving hardcaml]

let pack left_or_right value =
  { value = Bits.of_unsigned_int ~width value
  ; left_or_right = Left_or_right.Of_bits.of_enum left_or_right
  }
  |> Of_bits.pack
  |> Bits.to_unsigned_int
;;

let unpack value =
  value |> Signal.sel_bottom ~width:sum_of_port_widths |> Of_signal.unpack
;;
