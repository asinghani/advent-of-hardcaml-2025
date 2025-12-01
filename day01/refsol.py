# My reference solution, in python
import sys

with open(sys.argv[1]) as f:
    dat = f.readlines()

dat = [x.strip() for x in dat]
dat = [x.replace("L", "-").replace("R", "") for x in dat]
dat = [int(x) for x in dat]

pos = 50
cnt1 = 0
cnt2 = 0

for x in dat:
    sgn = 1 if x > 0 else -1
    for _ in range(abs(x)):
        pos = (pos + sgn) % 100
        if pos == 0:
            cnt2 += 1

    if pos == 0:
        cnt1 += 1

print("Part 1:", cnt1)
print("Part 2:", cnt2)
