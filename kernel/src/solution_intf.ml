(** Module type implemented by each individual day *)

open! Core

module type S = sig
  val identifier : string

  val parser
    : [ `Both_parts of (module Parser.S)
      | `Each_part of (module Parser.S) * (module Parser.S)
      ]

  (** Most of the time, it is easiest to implement pt1 and pt2 in the same design, as they
      can share intermediate state. However sometimes it is cleaner to do it separately,
      so the option is exposed as a variant. *)
  val design
    : [ `Both_parts of (module Design.S)
      | `Each_part of (module Design.S) * (module Design.S)
      ]
end

module type Solution = sig
  module type S = S
end
