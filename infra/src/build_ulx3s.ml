open! Core
open! Hardcaml
open! Advent_of_fpga_kernel

let ( ^/ ) = Filename.concat
let constraints = [%embed_file_as_string "infra/src/constraints.lpf"]

let designs =
  Solutions.solutions
  |> List.concat_map ~f:(fun (module Solution : Solution.S) ->
    match Solution.design with
    | `Both_parts design -> [ Solution.identifier, design ]
    | `Each_part (pt1_design, pt2_design) ->
      [ Solution.identifier ^ "-pt1", pt1_design
      ; Solution.identifier ^ "-pt2", pt2_design
      ])
;;

let command_exn ~workdir command =
  match Core_unix.system command with
  | Ok _ -> ()
  | Error error ->
    raise_s
      [%message
        "Error during command"
          (command : string)
          ~log_dir:(workdir : string)
          (error : Core_unix.Exit_or_signal.error)]
;;

let generate_rtl (module Design : Design.S) () =
  let open Ulx3s_top.Make (Design) in
  let module Circuit = Circuit.With_interface (I) (O) in
  let scope = Scope.create ~flatten_design:false ~auto_label_hierarchical_ports:true () in
  let circuit = Circuit.create_exn ~name:"hardcaml_ulx3s_top" (create scope) in
  let database = Scope.circuit_database scope in
  Rtl.create ~database Rtl.Language.Verilog [ circuit ]
  |> Rtl.full_hierarchy
  |> Rope.to_string
;;

let synth_project (module Design : Design.S) () =
  let rtl = generate_rtl (module Design) () in
  let workdir = Filename_unix.temp_dir "fpgabuild" "" in
  (* Write the temporary files *)
  Out_channel.with_file (workdir ^/ "top.sv") ~f:(fun oc ->
    Out_channel.output_string oc rtl);
  Out_channel.with_file (workdir ^/ "constraints.lpf") ~f:(fun oc ->
    Out_channel.output_string oc constraints);
  command_exn
    ~workdir
    [%string
      "yosys -p 'read_verilog -sv %{workdir}/top.sv; synth_ecp5 -json \
       %{workdir}/synthesis.json -top hardcaml_ulx3s_top -no-rw-check; tee -o \
       %{workdir}/utilization.log stat' | tee %{workdir}/synth.log"];
  ()
;;

let build_project ~bitstream_path (module Design : Design.S) () =
  let rtl = generate_rtl (module Design) () in
  let workdir = Filename_unix.temp_dir "fpgabuild" "" in
  (* Write the temporary files *)
  Out_channel.with_file (workdir ^/ "top.sv") ~f:(fun oc ->
    Out_channel.output_string oc rtl);
  Out_channel.with_file (workdir ^/ "constraints.lpf") ~f:(fun oc ->
    Out_channel.output_string oc constraints);
  let extra_synth_args =
    Design.design_config.ulx3s_extra_synth_args |> String.concat ~sep:" "
  in
  command_exn
    ~workdir
    [%string
      "yosys -p 'read_verilog -sv %{workdir}/top.sv; synth_ecp5 -json \
       %{workdir}/synthesis.json -top hardcaml_ulx3s_top -no-rw-check \
       %{extra_synth_args}; tee -o %{workdir}/utilization.log stat' | tee \
       %{workdir}/synth.log"];
  command_exn ~workdir [%string "file -E %{workdir}/synthesis.json"];
  command_exn
    ~workdir
    [%string
      "nextpnr-ecp5 --85k --json %{workdir}/synthesis.json --lpf \
       %{workdir}/constraints.lpf --textcfg %{workdir}/pnr_out.config | tee \
       %{workdir}/pnr.log"];
  command_exn ~workdir [%string "file -E %{workdir}/pnr_out.config"];
  command_exn
    ~workdir
    [%string
      "ecppack --compress %{workdir}/pnr_out.config %{workdir}/bitstream.bit | tee \
       %{workdir}/ecppack.log"];
  command_exn ~workdir [%string "file -E %{workdir}/bitstream.bit"];
  command_exn ~workdir [%string "cp %{workdir}/bitstream.bit %{bitstream_path}"];
  command_exn ~workdir [%string "cat %{workdir}/utilization.log"];
  print_endline [%string "Bitstream saved to %{bitstream_path}"];
  print_endline [%string "Logs saved to %{workdir}"];
  ()
;;

let rtl_command =
  designs
  |> List.map ~f:(Tuple2.map_snd ~f:generate_rtl)
  |> List.map
       ~f:
         (Tuple2.map_snd ~f:(fun fn ->
            Command.basic
              ~summary:"Generate RTL"
              (let%map_open.Command () = return () in
               fun () -> print_endline (fn ()))))
  |> Command.group ~summary:"Generate RTL for each design"
;;

let synth_command =
  designs
  |> List.map ~f:(fun (name, (module Design : Design.S)) ->
    name, synth_project (module Design))
  |> List.map
       ~f:
         (Tuple2.map_snd ~f:(fun fn ->
            Command.basic
              ~summary:"Synthesize the design"
              (let%map_open.Command () = return () in
               fun () -> fn ())))
  |> Command.group ~summary:"Synthesize each design"
;;

let build_command =
  designs
  |> List.map ~f:(fun (name, (module Design : Design.S)) ->
    name, build_project ~bitstream_path:(name ^ ".bit") (module Design))
  |> List.map
       ~f:
         (Tuple2.map_snd ~f:(fun fn ->
            Command.basic
              ~summary:"Build the design"
              (let%map_open.Command () = return () in
               fun () -> fn ())))
  |> Command.group ~summary:"Build each design"
;;

let command =
  Command.group
    ~summary:"Advent of FPGA"
    [ "rtl", rtl_command; "synth", synth_command; "build", build_command ]
;;
