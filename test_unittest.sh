#!/usr/bin/env bash

# test_unittest.sh
#
# Unit testing for unittest.sh

# shellcheck source=unittest.sh
source unittest.sh

testcase_num_collect_tests() {
  this_test "checks number of collected test cases"
  [ ${#__unittest_tests[@]} -eq 1 ]
}

unittest_run "$@"
