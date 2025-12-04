# My reference solution, in python
import sys

with open(sys.argv[1]) as f:
    dat = f.read().strip()

dat = dat.splitlines()
dat = [[int(a) for a in x] for x in dat]

def biggest_joltage(l, n):
    length = len(l)
    tmp = [0] * n

    for i in range(length):
        remaining = length - i

        for j in range(n):
            if l[i] > tmp[j] and remaining >= (n - j):
                tmp[j] = l[i]
                for k in range(j+1, n): tmp[k] = 0
                break

    return int("".join([str(x) for x in tmp]))

s1 = 0
s2 = 0

for x in dat:
    s1 += biggest_joltage(x, 2)
    s2 += biggest_joltage(x, 12)

print("Part 1:", s1)
print("Part 2:", s2)
