open! Core
open! Hardcaml
open! Advent_of_fpga_kernel
open! Advent_of_fpga_utils
include Advent_of_fpga_kernel.Design.Include
open Signal

let clock_freq = Clock_freq.Clock_25mhz

let design_config =
  { Design_config.default with clock_freq; ulx3s_extra_synth_args = [ "-noflatten" ] }
;;

let line_length_bits = 7 (* max len = 128 *)
let max_line_length = 1 lsl line_length_bits
let sequence_lens = [| 2; 12 |]

(* Compare a signal with a char *)
let ( ==:& ) a b = a ==:. Char.to_int b

module States = struct
  type t =
    | Read_input_line
    | Iterate_over_range
    | Add_result
    | Flush_pipeline
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let proc_arr = Fn.compose Always.proc Array.to_list

let create
      scope
      ({ clock
       ; clear
       ; uart_rx_data = byte_in
       ; uart_rx_control
       ; uart_rx_overflow
       ; uart_tx_ready
       } :
        _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let end_of_input = uart_rx_control.valid &: (uart_rx_control.value ==:. 1) in
  let open Always in
  let%hw.State_machine sm = State_machine.create (module States) spec in
  let%hw_var len_count = Variable.reg spec ~width:line_length_bits in
  let%hw_var iter_count = Variable.reg spec ~width:line_length_bits in
  let%hw_var write_en = Variable.wire ~default:gnd () in
  let%hw_var uart_rx_ready = Variable.wire ~default:gnd () in
  let results =
    Array.map sequence_lens ~f:(Array.init ~f:(fun _ -> Variable.reg spec ~width:4))
  in
  let%hw_var result_valid = Variable.wire ~default:gnd () in
  let%hw ram_read =
    Ram.create
      ~collision_mode:Read_before_write
      ~size:max_line_length
      ~write_ports:
        [| { write_clock = clock
           ; write_address = len_count.value
           ; write_enable = write_en.value
           ; write_data = Bcd_utils.ascii_to_bcd byte_in.value
           }
        |]
      ~read_ports:
        [| { read_clock = clock; read_address = iter_count.value; read_enable = vdd } |]
      ()
    |> (Fn.flip Array.get) 0
  in
  let%hw ram_read_addr = reg spec iter_count.value in
  let%hw remaining = len_count.value -: ram_read_addr in
  compile
    [ sm.switch
        [ ( Read_input_line
          , [ uart_rx_ready <-- vdd
            ; when_
                byte_in.valid
                [ if_
                    (byte_in.value ==:& '\n')
                    [ iter_count <--. 0; sm.set_next Iterate_over_range ]
                  @@ elif
                       (Bcd_utils.is_ascii_number byte_in.value)
                       [ write_en <-- vdd; incr len_count ]
                  @@ [ (* Ignore invalid byte *) ]
                ]
            ; when_ end_of_input [ sm.set_next Flush_pipeline ]
            ] )
        ; ( Iterate_over_range
          , [ (* Generate separate logic for part 1 and part 2 *)
              Array.map2_exn sequence_lens results ~f:(fun sequence_len result ->
                (* Generate a chained check for each digit that could be
                   updated in the result. This seems inefficient but is
                   actually only a few layers of logic (all of the comparisons
                   happen in parallel, followed by effectively a priority
                   encoder). Then update the relevant digits in the result. *)
                Array.init sequence_len ~f:Fn.id
                |> Array.fold_right
                     ~f:(fun i acc ->
                       [ if_
                           (iter_count.value
                            <>:. 0
                            &: (ram_read >: result.(i).value)
                            &: (remaining >=:. sequence_len - i))
                           [ result.(i) <-- ram_read
                           ; Array.mapi result ~f:(fun j x ->
                               if j > i then x <--. 0 else proc [])
                             |> proc_arr
                           ]
                         @@ acc
                       ])
                     ~init:[]
                |> proc)
              |> proc_arr
            ; incr iter_count
            ; when_ (iter_count.value ==: len_count.value) [ sm.set_next Add_result ]
            ] )
        ; ( Add_result
          , [ sm.set_next Read_input_line
            ; iter_count <--. 0
            ; len_count <--. 0
            ; result_valid <-- vdd
            ; Array.concat_map results ~f:(Array.map ~f:(fun x -> x <--. 0)) |> proc_arr
            ] )
        ; ( Flush_pipeline
          , [ (* Kind of hacky but good enough *)
              Fsm_utils.after_n_clocks ~clock ~clear ~n:10 [ sm.set_next Done ]
            ] )
        ; Done, []
        ]
    ];
  (* Convert back to binary and add up the results *)
  let%hw_array accumulators =
    results
    |> Array.map ~f:(fun result ->
      Bcd_utils.bcd_to_binary
        ~clock
        ~clear
        { valid = result_valid.value
        ; value = result |> Array.map ~f:Variable.value |> Array.to_list |> concat_msb
        })
    |> Array.map ~f:(fun { value; valid } ->
      reg_fb spec ~width:60 ~enable:valid ~f:(fun x -> x +: uresize ~width:60 value))
  in
  let done_ = sm.is Done in
  let%tydi { uart_tx } =
    Print_decimal_outputs.hierarchical
      scope
      { clock
      ; clear
      ; part1 = accumulators.(0)
      ; part2 = accumulators.(1)
      ; done_
      ; uart_tx_ready
      }
  in
  { board_leds = uextend ~width:8 done_; uart_tx; uart_rx_ready = uart_rx_ready.value }
;;

let hierarchical scope i =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~here:[%here] ~scope create i
;;
