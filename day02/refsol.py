# My reference solution, in python
import sys

with open(sys.argv[1]) as f:
    dat = f.read().strip()

dat = dat.split(",")
dat = [x.split("-") for x in dat]

s1 = 0
s2 = 0

for a, b in dat:
    for i in range(int(a), int(b)+1):
        si = str(i)
        for n in range(2, len(si)+1):
            if len(si) % n == 0:
                if si == n*si[:len(si)//n]:
                    if n == 2: s1 += i 
                    s2 += i
                    break

print("Part 1:", s1)
print("Part 2:", s2)
