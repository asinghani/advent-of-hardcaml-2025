open! Core
open! Hardcaml

module Cases = struct
  type t =
    | Left
    | Right
  [@@deriving sexp_of, compare ~localize, enumerate]

  let of_char = function
    | 'L' -> Left
    | 'R' -> Right
    | _ -> failwith "invalid"
  ;;
end

include Enum.Make_binary (Cases)
