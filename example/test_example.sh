#!/usr/bin/env bash

# test_exmple.sh
#
# A sample test script for unittest.sh.

# shellcheck source=unittest.sh
source ../unittest.sh

testcase_add() {
  it "adds numbers using bc"
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

testcase_run() {
  it "gets the word 'bar' with cut command"
  run echo 'foo bar baz' | cut -d' ' -f2
  [ "$status" -eq 0 ]
  [ "$output" = "bar" ]
}

foo() {
  return 1
}

testcase_skip() {
  it "is skipped"
  skip "foo command return 0 but not now"
  run foo
  [ "$status" -eq 0 ]
}

testcase_fail() {
  it "always fails"
  false
}

unittest_run "$@"
