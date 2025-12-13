open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness

include Advent_of_fpga_utils.Ascii_integer_parser.Make (struct
    let max_num_digits = 3
  end)

module Harness = Cyclesim_harness.Make (I) (O)

let ( <--. ) = Bits.( <--. )
let bits_to_char x = x |> Bits.to_char |> Char.sexp_of_t |> Sexp.to_string

let%expect_test "Simple test with printing waveforms directly" =
  let display_rules =
    let rule x wave_format =
      Display_rule.port_name_matches ~wave_format (Re.Glob.glob x |> Re.compile)
    in
    [ rule "clock" (Bit_or Hex)
    ; rule "byte_in$value" (Custom bits_to_char)
    ; rule "parsed_value" Unsigned_int
    ; rule "parsed_value_valid" (Bit_or Hex)
    ; rule "separator" (Custom bits_to_char)
    ]
  in
  Harness.run_advanced
    ~create:(hierarchical ~instance:"dut")
    ~trace:`Ports_only
    ~random_initial_state:`None
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:20
        ~display_width:95
        ~wave_width:1
        waves)
    (fun sim ->
       let inputs = Cyclesim.inputs sim in
       Cyclesim.cycle sim;
       "xy 1:456-78\n9\n10+"
       |> String.to_list
       |> List.iter ~f:(fun c ->
         inputs.byte_in.value <--. Char.to_int c;
         inputs.byte_in.valid := Bits.vdd;
         Cyclesim.cycle sim));
  [%expect
    {|
    ┌Signals───────────┐┌Waves────────────────────────────────────────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘│
    │                  ││────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬─── │
    │byte_in$value     ││ "\.│x  │y  │" "│1  │:  │4  │5  │6  │-  │7  │8  │"\.│9  │"\.│1  │0  │+   │
    │                  ││────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─── │
    │                  ││────────────────────┬───────┬───┬───┬───────┬───┬───────┬───────┬───┬─── │
    │parsed_value      ││ 0                  │1      │4  │45 │456    │7  │78     │9      │1  │10  │
    │                  ││────────────────────┴───────┴───┴───┴───────┴───┴───────┴───────┴───┴─── │
    │                  ││────────────────────┬───┬───────────┬───┬───────┬───┬───┬───┬───────┬─── │
    │parsed_value_valid││ 0                  │1  │0          │1  │0      │1  │0  │1  │0      │1   │
    │                  ││────────────────────┴───┴───────────┴───┴───────┴───┴───┴───┴───────┴─── │
    │                  ││────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬─── │
    │separator         ││ "\.│x  │y  │" "│1  │:  │4  │5  │6  │-  │7  │8  │"\.│9  │"\.│1  │0  │+   │
    │                  ││────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─── │
    └──────────────────┘└─────────────────────────────────────────────────────────────────────────┘
    |}]
;;
