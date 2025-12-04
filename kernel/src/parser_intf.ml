open! Core

(** A very minimal abstraction over the UART stream - any given byte is divided into
    either a data byte or a control byte, this can be used by the parser to differentiate
    sections of the parsed data. *)
module Symbol = struct
  type t =
    | Data_byte of char
    | Control_byte of char
  [@@deriving sexp]
end

module type S = sig
  val parse : string -> Symbol.t list
end

module type Parser = sig
  module type S = S

  module Symbol = Symbol
end
