#!/usr/bin/env bash

# test_unittest.sh
#
# Unit testing for unittest.sh

# shellcheck source=unittest.sh
source unittest.sh

testcase_num_collect_tests() {
  this_test "checks number of collected test cases"
  [ ${#_unittest_all_tests[@]} -eq 2 ]
}

testcase_make_word_plural() {
  this_test "makes a word plural correctly"

  [ "$(__make_word_plural "test" 0)" = "tests" ]
  [ "$(__make_word_plural "test" 1)" = "test" ]
  [ "$(__make_word_plural "test" 2)" = "tests" ]
  [ "$(__make_word_plural "failure" 0)" = "failures" ]
  [ "$(__make_word_plural "failure" 1)" = "failure" ]
  [ "$(__make_word_plural "failure" 2)" = "failures" ]
}

unittest_run "$@"
