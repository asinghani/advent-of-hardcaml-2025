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

### Day 3, Part 1 + Part 2

[Hardcaml solution](day03/src/day03_design.ml) // [Problem Link](https://adventofcode.com/2025/day/3)

The solution for this problem is to iterate and greedily take the largest value
for each digit (from the left), while enforcing that there are at least enough
digits left to construct the rest of the resultant number. Unfortunately, in
order to do this without hardcoding the line length, it has to do two passes
over each line, once to store and count the length of the line and a second
time to actually process it.

At each step in the iteration, it checks (in parallel for each of the result
digits) whether taking the current digit is both possible (enough remaining
digits) and is larger than the corresponding current digit in the result. It
then prioritizes the most-significant digit that it is able to take, clearing
out any later ones. Due to being able to do most of the logic in parallel
across all of the possible digits, this scales fairly well and doesn't require
much pipelining.

The whole thing is also generated twice, for sequence lengths of 2 and 12,
corresponding to parts 1 and 2.

### Day 2, Part 1 + Part 2

[Hardcaml solution](day02/src/day02_design.ml) // [Problem Link](https://adventofcode.com/2025/day/2)

I was quite satisfied with how this implementation turned out. It accepts the
input exactly as-is (in ASCII), and uses a small state-machine to shift in the
lower bound, then the upper bound (after it sees a dash); storing them in BCD
(binary-coded decimal). 

It then increments the lower bound until it reaches the upper bound (using a
simple BCD adder), each cycle feeding the counter into a pipelined checker
which compares each possible invalid ID format (using nested lists to generate
a parallel check for each possible length and number of repetitions), before
reducing them using a tree and adding up all of the detected mismatched IDs.

### Day 1, Part 1 + Part 2

[Hardcaml solution](day01/src/day01_design.ml) // [Problem Link](https://adventofcode.com/2025/day/1)

This implementation takes the simplest, slightly silly approach of simulating
every single tick that the combination lock moves through, and incrementing a
counter whenever it hits zero. This is very area-efficient (requires only a
couple of counters and a small state-machine) but not very time-efficient.

I might go back and implement the more efficient approach (using modular
arithmetic) at some point in the future.
