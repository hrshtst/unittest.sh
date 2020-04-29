#!/usr/bin/env bash

# test_unittest.sh
#
# Unit testing for unittest.sh

# shellcheck source=unittest.sh
source unittest.sh

copy_array() {
  local src="$1"
  local dst="$2"
  local src_repr="$(declare -p $src)"
  local src_elem="${src_repr#*=}"
  local src_type="${src_repr:9:1}"

  eval "declare -${src_type}g $dst="$src_elem
}

testcase_copy_array_list() {
  it "should copy elements of a list array to another variable"

  list1=("value1" "value2" "value3")
  copy_array list1 list2
  [ ${#list1[@]} -eq ${#list2[@]} ]
  [ "${list1[0]}" = "${list2[0]}" ]
  [ "${list1[1]}" = "${list2[1]}" ]
  [ "${list1[2]}" = "${list2[2]}" ]
}

testcase_copy_array_dict() {
  it "should copy elements of an associative array to another variable"

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

testcase_initialize() {
  it "should initialize variables used throughout running tests"

  # Given that fake values are assigned,
  _unittest_all_tests=("testcase_dummy")
  _unittest_tests_map=(["is a dummy test"]="testcase_dummy")
  _unittest_executed_tests=("testcase_dummy")
  _unittest_passed_tests=("testcase_dummy")
  _unittest_failed_tests=("testcase_dummy")
  _unittest_skipped_tests=("testcase_dummy")
  # When the function is called,
  _unittest_initialize
  # Then they are initialized.
  [ ${#_unittest_all_tests[@]} -eq 0 ]
  # [ ${#_unittest_tests_map[@]} -eq 0 ]
  [ ${#_unittest_executed_tests[@]} -eq 0 ]
  [ ${#_unittest_passed_tests[@]} -eq 0 ]
  [ ${#_unittest_failed_tests[@]} -eq 0 ]
  [ ${#_unittest_skipped_tests[@]} -eq 0 ]
}

testcase_reset_vars() {
  it "should reset variables to their defaults"
  reserved_description=$_unittest_description

  # Given that fake values are assigned,
  _unittest_description="testcase_dummy"
  _unittest_skip_note="skip the dummy test"
  _unittest_failed=true
  _unittest_skipped=true
  _unittest_err_source=("test_unittest.sh")
  _unittest_err_lineno=("105")
  _unittest_err_status=("1")
  status=1234
  output="hoge"
  lines=("hoge" "fuga" "foo")
  # When the variables are reset,
  _unittest_reset_vars
  # Then they are set to their defaults.
  [ -z $_unittest_description ]
  [ -z $_unittest_skip_note ]
  [ $_unittest_failed = false ]
  [ $_unittest_skipped = false ]
  [ ${#_unittest_err_source[@]} -eq 0 ]
  [ ${#_unittest_err_lineno[@]} -eq 0 ]
  [ ${#_unittest_err_status[@]} -eq 0 ]
  [ $status -eq 0 ]
  [ -z $output ]
  [ ${#lines[@]} -eq 0 ]

  _unittest_description=$reserved_description
}

mock_not_skip() {
  true
}

mock_skip() {
  skip
  false
}

mock_skip_handled() {
  skip
  return 0
  false
}

testcase_handle_not_skipped_test() {
  it "should do nothing for a test which is not skipped"

  # Given that a test case definition which is not going to be skipped,
  local test_def1="$(declare -f mock_not_skip)"
  # When the test case should not be skipped,
  _unittest_handle_skipped_test "mock_not_skip"
  # Then do nothing.
  local test_def2="$(declare -f mock_not_skip)"
  [ "$test_def1" = "$test_def2" ]
}

testcase_handle_skipped_test() {
  it "should handle a skipped test"

  # Given that a test case definition which is going to be skipped,
  # When the test case should be skipped,
  _unittest_handle_skipped_test "mock_skip"
  # Then add `return 0` shortly after the `skip` command.
  local test_def1="$(declare -f mock_skip | sed '1d')"
  local test_def2="$(declare -f mock_skip_handled | sed '1d')"
  [ "$test_def1" = "$test_def2" ]
}

testcase_categorize_by_result_passed() {
  it "should categorize a test into an appropriate group if it's passed"

  # Given that the test case is passed,
  _unittest_skipped=false
  _unittest_failed=false
  local testcase="testcase_dummy"
  _unittest_executed_tests=()
  _unittest_passed_tests=()
  _unittest_failed_tests=()
  _unittest_skipped_tests=()
  # When the function is executed,
  _unittest_categorize_by_result "$testcase"
  # Then the function is categorized into passed.
  [ "${_unittest_executed_tests[0]}" = "$testcase" ]
  [ "${_unittest_passed_tests[0]}" = "$testcase" ]
  [ ${#_unittest_failed_tests[@]} -eq 0 ]
  [ ${#_unittest_skipped_tests[@]} -eq 0 ]
}

testcase_categorize_by_result_failed() {
  it "should categorize a test into an appropriate group if it's failed"

  # Given that the test case is passed,
  _unittest_skipped=false
  _unittest_failed=true
  local testcase="testcase_dummy"
  _unittest_executed_tests=()
  _unittest_passed_tests=()
  _unittest_failed_tests=()
  _unittest_skipped_tests=()
  # When the function is executed,
  _unittest_categorize_by_result "$testcase"
  # Then the function is categorized into passed.
  [ "${_unittest_executed_tests[0]}" = "$testcase" ]
  [ ${#_unittest_passed_tests[@]} -eq 0 ]
  [ "${_unittest_failed_tests[0]}" = "$testcase" ]
  [ ${#_unittest_skipped_tests[@]} -eq 0 ]

  if ((${#_unittest_err_status[@]} == 0)); then
    _unittest_failed=false
  fi
}

testcase_categorize_by_result_skipped() {
  it "should categorize a test into an appropriate group if it's skipped"

  # Given that the test case is passed,
  _unittest_skipped=true
  _unittest_failed=false
  local testcase="testcase_dummy"
  _unittest_executed_tests=()
  _unittest_passed_tests=()
  _unittest_failed_tests=()
  _unittest_skipped_tests=()
  # When the function is executed,
  _unittest_categorize_by_result "$testcase"
  # Then the function is categorized into passed.
  [ "${_unittest_executed_tests[0]}" = "$testcase" ]
  [ ${#_unittest_passed_tests[@]} -eq 0 ]
  [ ${#_unittest_failed_tests[@]} -eq 0 ]
  [ "${_unittest_skipped_tests[0]}" = "$testcase" ]

  _unittest_skipped=false
}

testcase_it() {
  local _desc="should store the description of the test case"
  [ "$(_unittest_describe)" = "testcase_it" ]

  it "$_desc"
  [ "$(_unittest_describe)" = "$_desc" ]

  it
  [ "$(_unittest_describe)" = "anonymous test" ]

  it should store the description of the test case
  [ "$(_unittest_describe)" = "$_desc" ]
}

foo() {
  return 10
}

testcase_run_return_0() {
  it "should always return 0"
  local _status

  # No arguments.
  run
  _status=$?
  [ $_status -eq 0 ]

  # Provide arguments which exits with zero.
  run true
  _status=$?
  [ $_status -eq 0 ]

  # Provide arguments which exits with non-zero.
  run false
  _status=$?
  [ $_status -eq 0 ]
}

testcase_run_capture_status() {
  it "should capture status code returned by command with run"

  run foo
  [ $status -eq 10 ]
}

echo_stderr() {
  echo "$@" >&2
}

echo_whitebeard() {
  echo "Edward Newgate"
  echo "the Phoenix Marco" >&2
}

testcase_run_capture_output() {
  it "should capture output from arguments provided with the run command"

  # capture the standard output.
  run echo "the king of the pirates"
  [ "$output" = "the king of the pirates" ]

  # capture the standard error.
  run echo_stderr "the Fire Fist Ace"
  [ "$output" = "the Fire Fist Ace" ]

  # capture the standard output and the standard error.
  local expected=$'Edward Newgate\nthe Phoenix Marco'
  run echo_whitebeard
  [ "$output" = "$expected" ]
}

echo_straw_hat_pirates() {
  echo "Monkey D. Luffy"
  echo "Roronoa Zoro" >&2
  echo "Nami"
  echo "Usopp" >&2
  echo "Vinsmoke Sanji"
  echo "Tony Tony Chopper" >&2
  echo "Nico Robin"
  echo "Franky" >&2
  echo "Brook"
}

testcase_run_capture_lines() {
  it "should capture output from arguments provided with the run line by line"

  run echo_straw_hat_pirates
  [ "${lines[0]}" = "Monkey D. Luffy" ]
  [ "${lines[1]}" = "Roronoa Zoro" ]
  [ "${lines[2]}" = "Nami" ]
  [ "${lines[3]}" = "Usopp" ]
  [ "${lines[4]}" = "Vinsmoke Sanji" ]
  [ "${lines[5]}" = "Tony Tony Chopper" ]
  [ "${lines[6]}" = "Nico Robin" ]
  [ "${lines[7]}" = "Franky" ]
  [ "${lines[8]}" = "Brook" ]
}

testcase_run_throw_error_when_command_not_found() {
  it "should make run throw an error when command not found"

  local _status
  run hoge 2>/dev/null
  _status=$?
  _unittest_failed=false
  [ $_status -ne 0 ]
}

testcase_print_result_pass() {
  it "should print the result for a passed test case"

  run _unittest_print_result_pass
  [ "${lines[0]}" = " ✓ should print the result for a passed test case" ]
}

testcase_print_result_fail() {
  it "should print the result for a failed test case"

  false
  _unittest_failed=false
  run _unittest_print_result_fail
  [ "${lines[0]}" = "$(tput setaf 1) ✗ should print the result for a failed test case$(tput sgr0)" ]
  [ "${lines[1]}" = "$(tput setaf 9)   (in test file ./test_unittest.sh, line 336)" ]
  [ "${lines[2]}" = "     \`false' failed with 1$(tput sgr0)" ]
}

testcase_print_result_skip() {
  it "should print the result for a skipped test case"

  run _unittest_print_result_skip
  [ "${lines[0]}" = " - should print the result for a skipped test case (skipped)" ]

  _unittest_skip_note="this is skipped"
  run _unittest_print_result_skip
  [ "${lines[0]}" =\
    " - should print the result for a skipped test case (skipped: this is skipped)" ]
}

testcase_num_collect_tests() {
  it "should check number of collected test cases"

  [ ${#_unittest_all_tests[@]} -eq 20 ]
}

testcase_pluralize_regular() {
  it "should pluralize a regular noun based on its count"

  # case 1
  [ "$(pluralize test)" = "tests" ]
  [ "$(pluralize test 0)" = "tests" ]
  [ "$(pluralize test 1)" = "test" ]
  [ "$(pluralize test 2)" = "tests" ]
  # case 2
  [ "$(pluralize failure)" = "failures" ]
  [ "$(pluralize failure 0)" = "failures" ]
  [ "$(pluralize failure 1)" = "failure" ]
  [ "$(pluralize failure 2)" = "failures" ]
}

unittest_run "$@"
