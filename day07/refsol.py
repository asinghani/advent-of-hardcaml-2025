# My reference solution, in python
import sys, re, copy

with open(sys.argv[1]) as f:
    dat = f.read().strip().splitlines()
    dat = [x.strip() for x in dat]

width = len(dat[0])

window = ["." for x in range(3)]
count_shreg = [0 for x in range(width+1)]

def get(arr, i, default=None):
    if i < 0 or i >= len(arr):
        return default
    else:
        return arr[i]

cnt1 = 0
cnt2 = 0

for idx, line in enumerate(dat):
    is_last_row = (idx == (len(dat) - 1))
    for i, x in enumerate("." + line + "."):
        window = window[1:] + [x]

        if i < 2:
            continue

        if window[1] == "^":
            tmp = 0
        elif window[1] == "S":
            tmp += 1
        else:
            tmp = count_shreg[1]

        if window[0] == "^":
            tmp += count_shreg[0]

        if window[2] == "^":
            tmp += count_shreg[2]

        if window[1] == "^" and count_shreg[1] != 0:
            cnt1 += 1

        if is_last_row:
            cnt2 += tmp

        count_shreg = count_shreg[1:] + [tmp]

print(cnt1, cnt2)
