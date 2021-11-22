# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, re
# import
import libckhd


proc testRe(): void =
  var matches: array[1, string]
  # for def in tokenDefs:i
  let result = "# reload\nmore".match(re"(#.*)(?:$|\n)", matches)
  if result:
    echo "YES: ", $matches[0], " ", result
  else:
    echo $result

proc runTest(): bool =
  # let file = "../test.conf"
  let file = "./tests/test.conf"
  evalConfig(file)
  # let toknizer = makeTokenizer(chars, file)
  # echo toknizer.getTokens()
  # return true

test "can add":
  # check add(5, 5) == 10
  check runTest() == true
