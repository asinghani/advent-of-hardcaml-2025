open! Core
open! Hardcaml
open! Signal

module type S = sig
  type 'a t =
    { digits : 'a list (** The digits in the number, with index 0 being the LSB *) }
  [@@deriving hardcaml]

  val flatten : Signal.t t -> Signal.t
  val unflatten : Signal.t -> Signal.t t
  val zero : unit -> Signal.t t
  val one : unit -> Signal.t t

  (** Shift the provided digit into the LSB side of the given number. *)
  val shift_in : Signal.t t -> Signal.t -> Signal.t t

  (** Count the number of valid digits in the number. *)
  val num_digits : Signal.t t -> Signal.t

  module With_valid : With_valid.Wrap.S with type 'a value := 'a t

  val to_binary
    :  clock:Signal.t
    -> clear:Signal.t
    -> Signal.t With_valid.t
    -> Signal.t Hardcaml.With_valid.t
end

module type Bcd = sig
  module type S = S

  module Make (Config : sig
      val num_digits : int
    end) : S
end
