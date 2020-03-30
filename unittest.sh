#!/usr/bin/env bash

# unittest.sh
#
# This script provides a micro unit testing framework for bash shell
# scripts. Each test case consists of a short description and shell
# commands. Test cases are identified by the description each other.
# This framework does not provide any assertion command. Instead, it
# harnesses `errexit` option. If every command in the test case exits
# with a `0` status code, the test passes.
#
# The following code is an example usage of this framework.
#
# --
# #!/bin/bash
#
# source unittest.sh
#
# test_add() {
#   this_test "adds numbers using bc"
#   result="$(echo 2+2 | bc)"
#   [ "$result" -eq 4 ]
# }
#
# test_run() {
#   this_test "gets the word 'bar' with cut command"
#   run echo 'foo bar baz' | cut -d' ' -f2
#   [ "$status" -eq 0 ]
#   [ "$output" = "bar" ]
# }
#
# test_skip() {
#   this_test "is skipped"
#   skip "foo command returns 0 but not now"
#   run foo
#   [ "$status" -eq 0 ]
# }
#
# test_fail() {
#   this_test "always fails"
#   false
# }
#
# unittest_run "$@"
# ..
#
# Let's say this is saved as `test_example.sh`. Execute the script as
# a standard bash script, then output looks like this.
#
# --
# $ ./test_example.sh
# ✓ adds numbers using bc
# ✓ gets the word 'bar' with cut command
# - is skipped (skip: foo command returns 0 but not now)
# ✗ always fails
# (in test file test_example.sh, line 27)
#
# 4 tests, 1 failures, 1 skipped
# ..
#
# Each test case is defined as a function which starts with `test_`.
# Inside the test case a short description of the test should be put
# in the first line with a `this_test` helper command. Afterwards,
# standard shell commands can be written. If every command exits with
# `0` status, the test passes.
#
# A hepler command `run` invokes arguments as a bash command, then
# stores its exit code in a variable `$status`. The `run` command
# itself exits with `0` status code so that you can continue following
# asssertions. Also, the `$output` variable contains the contents of
# the standard output and the standard errors.
#
# To skip some test temporarily, you can use a `skip` command. The
# `skip` command accepts the reason for skipping as an optional
# argument.
#
# Additionally, `setup` and `teardown` functions can be defined, which
# are executed before and after each test case, respectively.
#
# Finally, a `unittest_run` command should be put with command line
# arguments to run all test cases and show results.
#
# Output format of the result and ideas of `run` and `skip` commands
# and `$status` and `$output` variables are adopted from the Bash
# Automated Testing System (a.k.a BATS), which is hosted on
# [https://github.com/sstephenson/bats] by Sam Stephenson and
# currently-maintained version on
# [https://github.com/bats-core/bats-core] by bats-core contributors.
# I reimplemented almost the same functionality, but do not their
# copyrights explicitly. I would like to thank them here.

__unittest_current_description=
this_test() {
  __unittest_current_description="$1"
}

run() {
  :
}

skip() {
  :
}

__unittest_tests=()
unittest_collect_tests() {
  local regex_tests
  regex_tests="^test_.*"

  while IFS= read -r func; do
    __unittest_tests+=("$func")
  done < <(declare -F | cut -d' ' -f3 | grep -e "$regex_tests")
}

unittest_run_tests() {
  local testcase

  for testcase in "${__unittest_tests[@]}"; do
    $testcase
  done
}

unittest_run() {
  unittest_collect_tests
  unittest_run_tests
}
