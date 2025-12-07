# My reference solution, in python
import sys, re
import functools

with open(sys.argv[1]) as f:
    dat = f.read().strip().splitlines()

max_width = 1024
max_digits = 4

cols = [[] for _ in range(max_width)]

sum0 = 0
sum1 = 0

def reduce(a, op):
    if op == "*":
        return functools.reduce(lambda a, b: a * b, a)
    elif op == "+":
        return functools.reduce(lambda a, b: a + b, a)
    else:
        assert False

# in hardware we can use a simple state machine here,
# but regex is quicker for modelling
for line in dat:
    for i, m in enumerate(re.finditer("(\\d{1,4}|\\*|\\+)", line)):
        offs = m.start()
        m = m.group()

        if m in ["*", "+"]:
            sum0 += reduce([int(x[1]) for x in cols[i]], m)

            identity_element = 1 if m == "*" else 0

            values = []
            for value_offs, value in cols[i]:
                num_digits = len(value)
                amt_padding_left = value_offs - offs
                amt_padding_right = (max_digits - (num_digits + amt_padding_left))
                padding_left = "x" * amt_padding_left
                padding_right = "x" * amt_padding_right

                values.append(list(
                    ("x" * amt_padding_left) + value + ("x" * amt_padding_right)
                ))
                
            # a lot of this is free (or almost free) in hardware
            values_t = ["".join(list(row)) for row in zip(*values)] 
            values_t = [x.replace("x", "") for x in values_t]
            values_t = [x or identity_element for x in values_t]
            values_t = [int(x) for x in values_t]

            sum1 += reduce(values_t, m)
        else:
            cols[i].append((offs, m))

print(sum0)
print(sum1)
