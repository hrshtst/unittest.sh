#!/usr/bin/env bash

# test_unittest.sh
#
# Unit testing for unittest.sh

# shellcheck source=unittest.sh
source unittest.sh

copy_array() {
  local src="$1"
  local dst="$2"
  local src_repr="$(declare -p $1)"
  local src_elem="${src_repr#*=}"
  local src_type="${src_repr:9:1}"

  eval "declare -${src_type}g $dst="$src_elem
}

testcase_copy_array_list() {
  this_test "should copy elements of a list array to another variable"

  list1=("value1" "value2" "value3")
  copy_array list1 list2
  [ ${#list1[@]} -eq ${#list2[@]} ]
  [ "${list1[0]}" = "${list2[0]}" ]
  [ "${list1[1]}" = "${list2[1]}" ]
  [ "${list1[2]}" = "${list2[2]}" ]
}

testcase_copy_array_dict() {
  this_test "should copy elements of an associative array to another variable"

  declare -A dict1=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
  copy_array dict1 dict2
  [ ${#dict1[@]} -eq ${#dict2[@]} ]
  [ "${dict1[key1]}" = "${dict2[key1]}" ]
  [ "${dict1[key2]}" = "${dict2[key2]}" ]
  [ "${dict1[key3]}" = "${dict2[key3]}" ]
}

setup() {
  copy_array _unittest_all_tests reserved_all_tests
  # copy_array _unittest_tests_map reserved_tests_map
  copy_array _unittest_executed_tests reserved_executed_tests
  copy_array _unittest_passed_tests reserved_passed_tests
  copy_array _unittest_failed_tests reserved_failed_tests
  copy_array _unittest_skipped_tests reserved_skipped_tests
}

teardown() {
  copy_array reserved_all_tests _unittest_all_tests
  # copy_array reserved_tests_map _unittest_tests_map
  copy_array reserved_executed_tests _unittest_executed_tests
  copy_array reserved_passed_tests _unittest_passed_tests
  copy_array reserved_failed_tests _unittest_failed_tests
  copy_array reserved_skipped_tests _unittest_skipped_tests
}

testcase_num_collect_tests() {
  this_test "should check number of collected test cases"

  [ ${#_unittest_all_tests[@]} -eq 5 ]
}

testcase_initialize() {
  this_test "should initialize variables used throughout running tests"

  # assign fake values
  _unittest_all_tests=("testcase_dummy")
  _unittest_tests_map=(["is a dummy test"]="testcase_dummy")
  _unittest_executed_tests=("testcase_dummy")
  _unittest_passed_tests=("testcase_dummy")
  _unittest_failed_tests=("testcase_dummy")
  _unittest_skipped_tests=("testcase_dummy")

  _unittest_initialize

  [ ${#_unittest_all_tests[@]} -eq 0 ]
  # [ ${#_unittest_tests_map[@]} -eq 0 ]
  [ ${#_unittest_executed_tests[@]} -eq 0 ]
  [ ${#_unittest_passed_tests[@]} -eq 0 ]
  [ ${#_unittest_failed_tests[@]} -eq 0 ]
  [ ${#_unittest_skipped_tests[@]} -eq 0 ]
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
