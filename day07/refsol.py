# My reference solution, in python
import sys, re, copy

with open(sys.argv[1]) as f:
    dat = f.read().strip().splitlines()
    dat = [x.strip() for x in dat]

width = len(dat[0])

last = ["." for x in range(width)]
cur = ["." for x in range(width)]

cnt = 0

for line in dat:
    for i in range(width):
        out = "."
        if line[i] == "^":
            out = "^"

            if last[i] == "|":
                cnt += 1

        elif line[i] == "S":
            out = "S"

        elif line[i] == ".":
            out = "."

            if last[i] == "S":
                out = "|"
            elif last[i] == "|":
                out = "|"
            elif i > 0 and last[i-1] == "|" and line[i-1] == "^":
                out = "|"
            elif i < (width-1) and last[i+1] == "|" and line[i+1] == "^":
                out = "|"

        else:
            assert False

        cur[i] = out

    last = copy.deepcopy(cur)

print(cnt)
