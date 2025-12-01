open! Core
open! Async

type t

val create : baud:int -> string -> t Deferred.t
val close : t -> unit Deferred.t
val read_char : t -> char Deferred.t
val read_line : t -> string Deferred.t
val flush : t -> unit Deferred.t
val write_bytes : ?flush:bool -> ?pos:int -> ?len:int -> t -> bytes -> unit Deferred.t
val write_char : ?flush:bool -> t -> char -> unit Deferred.t
val write_line : ?flush:bool -> t -> string -> unit Deferred.t
