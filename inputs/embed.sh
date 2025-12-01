#!/bin/bash

# Embed all of the inputs into one text file to allow embedding it into the
# OCaml input parser binaries

for file in *.txt ../examples_for_testing/inputs/*.txt; do
  fname=$(basename "$file")
  b64=$(base64 -w 0 "$file")
  echo "$fname $b64"
done
