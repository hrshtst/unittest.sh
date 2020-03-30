#!/usr/bin/env bash

# test_unittest.sh
#
# Unit testing for unittest.sh

# shellcheck source=unittest.sh
source unittest.sh

test_collect_tests() {
  this_test ""
  echo "executing: ${FUNCNAME[0]}"
  [ ${#__unittest_tests[@]} -eq 1 ]
}

unittest_run "$@"
