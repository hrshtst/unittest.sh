#!/usr/bin/env bash

# test_unittest.bash
#
# Unit testing for unittest.bash

# shellcheck source=unittest.bash
source unittest.bash

testcase_num_collect_tests() {
  this_test "checks number of collected test cases"
  [ ${#__unittest_tests[@]} -eq 2 ]
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
