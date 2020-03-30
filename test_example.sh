#!/usr/bin/env bash

# test_exmple.sh
#
# A sample test script for unittest.sh.

source unittest.sh

test_add() {
  this_test "adds numbers using bc"
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

test_run() {
  this_test "gets the word 'bar' with cut command"
  run echo 'foo bar baz' | cut -d' ' -f2
  [ "$status" -eq 0 ]
  [ "$output" = "bar" ]
}

foo() {
  return 1
}

test_skip() {
  this_test "is skipped"
  skip "foo command return 0 but not now"
  run foo
  [ "$status" -eq 0 ]
}

test_fail() {
  this_test "always fails"
  false
}

unittest_run "$@"
