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
# testcase_add() {
#   this_test "adds numbers using bc"
#   result="$(echo 2+2 | bc)"
#   [ "$result" -eq 4 ]
# }
#
# testcase_run() {
#   this_test "gets the word 'bar' with cut command"
#   run echo 'foo bar baz' | cut -d' ' -f2
#   [ "$status" -eq 0 ]
#   [ "$output" = "bar" ]
# }
#
# testcase_skip() {
#   this_test "is skipped"
#   skip "foo command returns 0 but not now"
#   run foo
#   [ "$status" -eq 0 ]
# }
#
# testcase_fail() {
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
# Each test case is defined as a function which starts with
# `testcase_`. Inside the test case a short description of the test
# should be put in the first line with a `this_test` helper command.
# Afterwards, standard shell commands can be written. If every command
# exits with `0` status, the test passes.
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

# Contains a filename of the currently executing script.
__unittest_script_filename="${BASH_SOURCE[1]}"

# Contains the current working directory.
__unittest_working_directory="$(pwd)"

# Keeps the state whether a test case is failed or not. When it is set
# to `true`, it means the most recent test case failed. It should be
# set to false prior to running each test case.
__unittest_failed=false

# When a test case is skipped, this flag is set to `true`. It should
# be set to false prior to running each test case.
__unittest_skipped=false

# Contains a function name which is about to run or currently running
# as a test case. Its value should start with 'testcase_' so as to be
# collected automatically by `unittest_collect_testcases`.
__unittest_testcase=

# Contains a string which describes a test case being about to run or
# currently running.
__unittest_description=

# Contains a string of notes why a test case is skipped. It is given
# as an argument of `skip` command.
__unittest_skip_note=

# Contains all the collected function names given as test cases. It
# includes skipped tests.
__unittest_tests=()

# Contains function names of passed test cases.
__unittest_passed_tests=()

# Contains function names of failed test cases.
__unittest_failed_tests=()

# Contains function names of skipped test cases.
__unittest_skipped_tests=()

# Declared as an associative array which contains function names of
# test cases as values indexed by descriptions of the test.
declare -A __unittest_tests_map

set -o errtrace

#
__unittest_on_failed() {
  local _status="$?"

  if [[ "${BASH_SOURCE[1]}" = "$__unittest_script_filename" ]]; then
    __unittest_failed=true
  fi
}

trap "__unittest_on_failed" ERR

this_test() {
  __unittest_description="$1"
}

run() {
  :
}

skip() {
  __unittest_skip_note="$1"
}

unittest_setup() {
  :
}

__unittest_preprocesses() {
  __unittest_testcase="$1"
  __unittest_failed=false
}

__unittest_postprocesses() {
  if [[ $__unittest_skipped = true ]]; then
    __unittest_skipped_tests+=("$__unittest_testcase")
  elif [[ $__unittest_failed = true ]]; then
    __unittest_failed_tests+=("$__unittest_testcase")
  else
    __unittest_passed_tests+=("$__unittest_testcase")
  fi
}

__unittest_print_result_pass() {
  printf " ✓ %s\n" "$__unittest_description"
}

__unittest_print_result_fail() {
  printf " ✗ %s\n" "$__unittest_description"
}

__unittest_print_result_skip() {
  printf " - %s\n" "$__unittest_description"
}

__unittest_print_result() {
  if [[ $__unittest_skipped = true ]]; then
    __unittest_print_result_skip
  elif [[ $__unittest_failed = true ]]; then
    __unittest_print_result_fail
  else
    __unittest_print_result_pass
  fi
}

unittest_collect_testcases() {
  local regex_tests
  regex_tests="^testcase_.*"

  while IFS= read -r func; do
    __unittest_tests+=("$func")
  done < <(declare -F | cut -d' ' -f3 | grep -e "$regex_tests")
}

unittest_run_testcases() {
  local testcase

  for testcase in "${__unittest_tests[@]}"; do
    __unittest_preprocesses "$testcase"
    $__unittest_testcase
    __unittest_postprocesses
    __unittest_print_result
  done
}

__make_word_plural() {
  local word n
  word="$1"
  n="$2"

  if (( n == 1 )); then
    echo "$word"
  else
    echo "${word}s"
  fi
}

unittest_print_summary() {
  local n_tests n_failed n_skipped
  local summary

  # store numbers of executed tests in variables
  n_tests=${#__unittest_tests[@]}
  n_failed=${#__unittest_failed_tests[@]}
  n_skipped=${#__unittest_skipped_tests[@]}

  # make summary text
  summary=""
  summary+="$(printf "%d %s" $n_tests "$(__make_word_plural test $n_tests)")"
  summary+="$(printf ", %d %s" $n_failed "$(__make_word_plural failure $n_failed)")"
  if (( n_skipped > 0 )); then
    summary+="$(printf ", %d skipped" $n_skipped)"
  fi

  # output
  printf "\n%s\n" "$summary"
}

unittest_run() {
  unittest_setup
  unittest_collect_testcases
  unittest_run_testcases
  unittest_print_summary
}
