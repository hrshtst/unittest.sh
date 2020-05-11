#!/usr/bin/env bash

# test_unittest.sh
#
# Unit testing for unittest.sh

# shellcheck source=unittest.sh
source unittest.sh


### Testing of methods used in this script privately.

# The `copy_array` function takes two variable names as arguments. The
# first argument is the source variable to be copied, and the second
# one is the destination to be newly created. The destination variable
# will be declared as the same type as the source. This function is
# used only in this script, so it is not related with unittest.sh.
# Note that this function always declares the destination variable as
# a global one.
copy_array() {
  local src="$1"
  local dst="$2"
  (( $# == 2 )) || return 1

  local repr
  local elem
  local type
  repr="$(declare -p "$src")"
      # => declare -a src=([0]="value1" [1]="value2" [2]="value3")
  elem="${repr#*=}" # => ([0]="value1" [1]="value2" [2]="value3")
  type="$(echo "$repr" | cut -d' ' -f2)" # => -a

  # Unset a variable in case the variable name conflicts
  unset -v $dst

  # NOTE: $dst is declared as a global variable to make it visible
  # outside from this function.
  eval "declare ${type}g $dst=$elem"
}

testcase_copy_array() {
  it "copy_array" "should copy elements of an array to another"

  local array1
  array1=([0]="value1" [1]="value2" [2]="value3")
  array2=()
  copy_array array1 array2
  [ ${#array1[@]} -eq ${#array2[@]} ]
  [ "${array1[0]}" = "${array2[0]}" ]
  [ "${array1[1]}" = "${array2[1]}" ]
  [ "${array1[2]}" = "${array2[2]}" ]
}

testcase_copy_associative_array() {
  it "copy_array" "should copy elements of an associative array to another"

  declare -A array1
  array1=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
  array2=()
  copy_array array1 array2
  [ ${#array1[@]} -eq ${#array2[@]} ]
  [ "${array1[key1]}" = "${array2[key1]}" ]
  [ "${array1[key2]}" = "${array2[key2]}" ]
  [ "${array1[key3]}" = "${array2[key3]}" ]
}


### Testing of methods in `unittest.sh`.

# The unit testing framework `unittest.sh` uses global variables whose
# prefixes commonly starts with `_unittest`. Since this script aims to
# test methods in `unittest.sh` under the control of `unittest.sh`
# itself, either modifying or resetting the variables may cause a
# break of the testing framework. To prevent from going out of order,
# each global varialbe is stored in another prior to running each test
# case, and restore it to the original.
setup() {
  copy_array _unittest_all_tests reserved_all_tests
  copy_array _unittest_all_descriptions reserved_all_descriptions
  copy_array _unittest_specified_tests reserved_specified_tests
  copy_array _unittest_tests_to_run reserved_tests_to_run
  copy_array _unittest_executed_tests reserved_executed_tests
  copy_array _unittest_passed_tests reserved_passed_tests
  copy_array _unittest_failed_tests reserved_failed_tests
  copy_array _unittest_skipped_tests reserved_skipped_tests
}

teardown() {
  copy_array reserved_all_tests _unittest_all_tests
  copy_array reserved_all_descriptions _unittest_all_descriptions
  copy_array reserved_specified_tests _unittest_specified_tests
  copy_array reserved_tests_to_run _unittest_tests_to_run
  copy_array reserved_executed_tests _unittest_executed_tests
  copy_array reserved_passed_tests _unittest_passed_tests
  copy_array reserved_failed_tests _unittest_failed_tests
  copy_array reserved_skipped_tests _unittest_skipped_tests
}

testcase_initialize() {
  it "should initialize variables used throughout running tests"

  # Given that fake values are assigned,
  _unittest_all_tests=("testcase_dummy")
  _unittest_all_descriptions=("this is a dummy test")
  _unittest_specified_tests=("testcase_dummy")
  _unittest_tests_to_run=("testcase_dummy")
  _unittest_executed_tests=("testcase_dummy")
  _unittest_passed_tests=("testcase_dummy")
  _unittest_failed_tests=("testcase_dummy")
  _unittest_skipped_tests=("testcase_dummy")
  _unittest_flag_help=true
  _unittest_flag_list=true
  _unittest_flag_force=true
  # When the function is called,
  _unittest_initialize
  # Then they are initialized.
  [ ${#_unittest_all_tests[@]} -eq 0 ]
  [ ${#_unittest_all_descriptions[@]} -eq 0 ]
  [ ${#_unittest_specified_tests[@]} -eq 0 ]
  [ ${#_unittest_tests_to_run[@]} -eq 0 ]
  [ ${#_unittest_executed_tests[@]} -eq 0 ]
  [ ${#_unittest_passed_tests[@]} -eq 0 ]
  [ ${#_unittest_failed_tests[@]} -eq 0 ]
  [ ${#_unittest_skipped_tests[@]} -eq 0 ]
  [ $_unittest_flag_help = false ]
  [ $_unittest_flag_list = false ]
  [ $_unittest_flag_force = false ]
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
  [ "$(_unittest_describe)" = "testcase_it" ]

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

  local linenum
  linenum="$(grep -ne "^  false # should.*number" "$0" | cut -d':' -f1)"

  false # should appear this line number
  _unittest_failed=false
  run _unittest_print_result_fail
  [ "${lines[0]}" = "$(tput setaf 1) ✗ should print the result for a failed test case$(tput sgr0)" ]
  [ "${lines[1]}" = "$(tput setaf 9)   (in test file ./test_unittest.sh, line $linenum)" ]
  [ "${lines[2]}" = "     \`false # should appear this line number' failed with 1$(tput sgr0)" ]
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

testcase_endswith_return_0() {
  it "should return 0 if the word ends with the suffix"

  endswith "angry" "y"
  endswith "angry" "ry"
  endswith "angry" "gry"
}

testcase_endswith_return_1() {
  it "should return 1 if the word does not end with the suffix"

  run endswith "angry" "x"
  [ "$status" -eq 1 ]
  run endswith "angry" "gryx"
  [ "$status" -eq 1 ]
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

testcase_pluralize_ends_in_s() {
  it "should add -es to the end if the the noun ends in -s"

  # bus
  [ "$(pluralize bus)" = "buses" ]
  [ "$(pluralize bus 0)" = "buses" ]
  [ "$(pluralize bus 1)" = "bus" ]
  [ "$(pluralize bus 2)" = "buses" ]
  # brass
  [ "$(pluralize brass)" = "brasses" ]
  [ "$(pluralize brass 0)" = "brasses" ]
  [ "$(pluralize brass 1)" = "brass" ]
  [ "$(pluralize brass 2)" = "brasses" ]
}

_testcase_parse_flags_setup() {
  _unittest_initialize
  [ "$_unittest_flag_help" = false ]
  [ "$_unittest_flag_list" = false ]
  [ "$_unittest_flag_force" = false ]
}

testcase_parse_flags_help() {
  it "should set flags to show help message"

  _testcase_parse_flags_setup
  unittest_parse -h
  [ "$_unittest_flag_help" = true ]

  _testcase_parse_flags_setup
  unittest_parse --help
  [ "$_unittest_flag_help" = true ]
}

testcase_parse_flags_list() {
  it "should set flags to list available tests"

  _testcase_parse_flags_setup
  unittest_parse -l
  [ "$_unittest_flag_list" = true ]

  _testcase_parse_flags_setup
  unittest_parse --list-tests
  [ "$_unittest_flag_list" = true ]
}

testcase_parse_flags_force() {
  it "should set flags to force to run skipping tests"

  _testcase_parse_flags_setup
  unittest_parse -f
  [ "$_unittest_flag_force" = true ]

  _testcase_parse_flags_setup
  unittest_parse --force-run
  [ "$_unittest_flag_force" = true ]
}

testcase_parse_flags_unsupported() {
  it "should throw an error if unsupported option is supplied"

  _testcase_parse_flags_setup
  run unittest_parse -a
  [ "$status" -eq 1 ]
  [ "$output" = "$0: unsupported option: -a" ]

  _testcase_parse_flags_setup
  run unittest_parse --unknown
  [ "$status" -eq 1 ]
  [ "$output" = "$0: unsupported option: --unknown" ]
}

testcase_parse_flags_positional_args() {
  it "should store positional arguments to a variable"

  unittest_parse "should test something" "should check an awesome thing"
  [ "${_unittest_specified_tests[0]}" = "should test something" ]
  [ "${_unittest_specified_tests[1]}" = "should check an awesome thing" ]

  unittest_parse -f "test 01" "test 02"
  [ "$_unittest_flag_force" = true ]
  [ "${_unittest_specified_tests[0]}" = "test 01" ]
  [ "${_unittest_specified_tests[1]}" = "test 02" ]
}

testcase_collect_testcases_check_num() {
  it "should check the number of collected testcases"

  local n_testcases
  n_testcases="$(grep -e "^testcase_.*() {$" "$0" | wc -l)"

  [ "${#_unittest_all_tests[@]}" = "$n_testcases" ]
  [ "${#_unittest_all_descriptions[@]}" = "$n_testcases" ]
}

testcase_collect_testcases_dummy01() {
  it "this is a dummy test"
}

testcase_collect_testcases_dummy02() {
  it 'this is a dummy test which has a so so so so loooooooooong description'\
     'that it does not fit into one line'
}

testcase_collect_testcases_dummy03() {
  it ""
}

testcase_collect_testcases_dummy04() {
  it
}

testcase_collect_testcases_dummy05() {
  :
}

# testcase_collect_testcases_check_map() {
#   it "should check if the created map stores keys and values correctly"

#   local key="this is a dummy test"
#   [ "${_unittest_all_tests_map[$key]}" = "testcase_collect_testcases_dummy01" ]

#   key='this is a dummy test which has a so so so so loooooooooong description that it does not fit into one line'
#   [ "${_unittest_all_tests_map[$key]}" = "testcase_collect_testcases_dummy02" ]

#   # When no description is provided, the key should be its function name
#   key="testcase_collect_testcases_dummy03"
#   [ "${_unittest_all_tests_map[$key]}" = "$key" ]

#   key="testcase_collect_testcases_dummy04"
#   [ "${_unittest_all_tests_map[$key]}" = "$key" ]

#   key="testcase_collect_testcases_dummy05"
#   [ "${_unittest_all_tests_map[$key]}" = "$key" ]
# }

unittest_main "$@"
