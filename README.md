# Advent of Hardcaml 2025

My attempts at solving [Advent of Code 2025](https://adventofcode.com/)
challenges in Hardcaml. This is a follow-up to my attempt [last
year](https://blog.janestreet.com/advent-of-hardcaml-2024/) where I solved a
handful of challenges; this year's goal being to get as close as possible to
100% completion by the end of December.

**Do you think this is cool and want to try it for yourself?** I'm helping run an
[Advent of FPGA
Challenge](https://blog.janestreet.com/advent-of-fpga-challenge-2025/) where
you can try your own designs, show off the features of your favorite HDL
languages, and win some prizes!

## Implementation

I'm primarily targeting the ULX3S FPGA board, with the Lattice ECP5-85F FPGA
chip, mostly for it's compatibility with the open-source yosys+nextpnr
toolchain.

## Solutions

### Day 1, Part 1 + Part 2

[Hardcaml solution](day01/src/day01_design.ml) // [Problem Link](https://adventofcode.com/2025/day/1)

This implementation takes the simplest / slightly silly approach of simulating
every single tick that the combination lock moves through, and incrementing a
counter whenever it hits zero. This is very area-efficient (requires only a
couple of counters and a small state-machine) but not very time-efficient.

I might go back and implement the more efficient approach (using modular
arithmetic) at some point in the future.
