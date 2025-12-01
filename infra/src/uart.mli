open! Core
open! Hardcaml
open! Signal

(** Simple UART transciever with build-time configurability and built-in RX and TX FIFOs *)
module Make (Config : sig
    val baud : int
    val clock_freq_hz : int
    val rx_fifo_depth : int
    val tx_fifo_depth : int
  end) : sig
  module Rx : sig
    module I : sig
      type 'a t =
        { clock : 'a
        ; clear : 'a
        ; ready : 'a
        ; rx : 'a
        }
      [@@deriving hardcaml]
    end

    module O : sig
      type 'a t =
        { byte_out : 'a With_valid.t
        ; fifo_overflow : 'a
        }
      [@@deriving hardcaml]
    end

    val create : Scope.t -> Signal.t I.t -> Signal.t O.t
  end

  module Tx : sig
    module I : sig
      type 'a t =
        { clock : 'a
        ; clear : 'a
        ; byte_in : 'a With_valid.t
        }
      [@@deriving hardcaml]
    end

    module O : sig
      type 'a t =
        { ready : 'a
        ; tx : 'a
        }
      [@@deriving hardcaml]
    end

    val create : Scope.t -> Signal.t I.t -> Signal.t O.t
  end
end
