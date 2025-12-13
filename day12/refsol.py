# My reference solution, in python
import sys, re
import functools

with open(sys.argv[1]) as f:
    dat = f.read().strip().splitlines()

count = 0

for line in dat:
    if "x" in line:
        ints = [int(x) for x in re.findall(r"\d+", line)]
        count += (ints[0] * ints[1]) >= (9 * sum(ints[2:]))


print(count)
