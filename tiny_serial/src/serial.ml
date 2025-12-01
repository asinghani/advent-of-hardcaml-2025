open! Core
open! Async

type t =
  { reader : Reader.t
  ; writer : Writer.t
  }

let create ~baud port =
  let%bind reader = Reader.open_file port in
  let%bind writer = Writer.open_file port in
  let fd = reader |> Reader.fd |> Fd.file_descr_exn in
  let attrs = Core_unix.Terminal_io.tcgetattr fd in
  let attrs =
    { attrs with
      c_icanon = false
    ; c_echo = false
    ; c_opost = false
    ; c_obaud = baud
    ; c_ibaud = baud
    ; c_csize = 8 (* data bits *)
    ; c_cstopb = 1 (* stop bits *)
    ; c_istrip = false
    ; c_inlcr = false
    ; c_igncr = false
    ; c_icrnl = false
    ; c_ignbrk = false
    }
  in
  Core_unix.Terminal_io.tcsetattr attrs fd ~mode:TCSANOW;
  return { reader; writer }
;;

let close t =
  let%bind () = Reader.close t.reader in
  Writer.close t.writer
;;

let read_result_ok_exn read_result =
  match read_result with
  | `Ok x -> x
  | `Eof -> failwith "EOF while reading from serial port"
;;

let read_char t = Reader.read_char t.reader >>| read_result_ok_exn
let read_line t = Reader.read_line t.reader >>| read_result_ok_exn

let flush t =
  let%map result = Writer.flushed_or_failed_with_result t.writer in
  match result with
  | Error | Consumer_left | Force_closed -> failwith "Failed to flush writer"
  | Flushed _ -> ()
;;

let write_bytes ?flush:(do_flush = true) ?pos ?len t b =
  Writer.write_bytes ?pos ?len t.writer b;
  if do_flush then flush t else return ()
;;

let write_char ?flush:(do_flush = true) t c =
  Writer.write_char t.writer c;
  if do_flush then flush t else return ()
;;

let write_line ?flush:(do_flush = true) t s =
  Writer.write_line t.writer s;
  if do_flush then flush t else return ()
;;
