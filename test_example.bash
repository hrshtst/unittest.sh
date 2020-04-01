#!/usr/bin/env bash

# test_exmple.bash
#
# A sample test script for unittest.bash.

# shellcheck source=unittest.bash
source unittest.bash

testcase_add() {
  this_test "adds numbers using bc"
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

status=0
output="bar"
testcase_run() {
  this_test "gets the word 'bar' with cut command"
  run echo 'foo bar baz' | cut -d' ' -f2
  [ "$status" -eq 0 ]
  [ "$output" = "bar" ]
}

foo() {
  return 1
}

testcase_skip() {
  this_test "is skipped"
  skip "foo command return 0 but not now"
  run foo
  [ "$status" -eq 0 ]
}

testcase_fail() {
  this_test "always fails"
  false
}

unittest_run "$@"
