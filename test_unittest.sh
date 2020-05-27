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
  unset -v "$dst"

  # NOTE: $dst is declared as a global variable to make it visible
  # outside from this function.
  eval "declare ${type}g $dst=$elem"
}

testcase_copy_array() {
  describe "copy_array" "should copy elements of an array to another"

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
  describe "copy_array" "should copy elements of an associative array to another"

  declare -A array1
  array1=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
  array2=()
  copy_array array1 array2
  [ ${#array1[@]} -eq ${#array2[@]} ]
  [ "${array1[key1]}" = "${array2[key1]}" ]
  [ "${array1[key2]}" = "${array2[key2]}" ]
  [ "${array1[key3]}" = "${array2[key3]}" ]
}


### Testing of utility functions in `unittest.sh`.

testcase_error() {
  describe "error" \
           "should output an error message with the caller and location"

  local lineno
  local _output

  lineno="$(grep -n "error \"this is an error message\"" "$0" | cut -d':' -f1)"
  _output="$(error "this is an error message" 2>&1)"
  [ "$_output" = "$0:$lineno [in testcase_error()] this is an error message" ]
}

testcase_error_show_no_extra_info() {
  describe "error" \
           "should output an error message without extra information"

  local _output

  _output="$(error "this is also an error message" false 2>&1)"
  [ "$_output" = "this is also an error message" ]
}

error_inside() {
  error "error message inside a function" true 1 2>&1
}

testcase_error_inside_function() {
  describe "error" \
           "should output an error message inside a function as well"

  local lineno
  local _output
  local expected

  lineno="$(grep -n "\"\$(error_inside)\"" "$0" | cut -d':' -f1)"
  _output="$(error_inside)"
  expected="$0:$lineno [in testcase_error_inside_function()] error message inside a function"
  [ "$_output" = "$expected" ]
}

testcase_error_in_run() {
  describe "error" \
           "should output an error message executed in run command"

  local lineno
  local expected

  lineno="$(grep -n "run error_inside\$" "$0" | cut -d':' -f1)"
  run error_inside
  expected="$0:$lineno [in testcase_error_in_run()] error message inside a function"
  [ "$output" = "$expected" ]
}

testcase_printcolln_error() {
  describe "printcolln should raise an error when arguments are invalid"

  local lineno
  local prefix
  local expected

  # wrong number of arguments
  lineno="$(grep -n "run printcolln \"error message\"\$" "$0" | cut -d':' -f1)"
  prefix="$0:$lineno [in ${FUNCNAME[0]}()] "
  expected="Take exactly 2 arguments, but provided 1"
  run printcolln "error message"
  [ $status = 1 ]
  [ "$output" = "$prefix$expected" ]

  # wrong color code
  lineno="$(grep -n "run printcolln 256 \"text\"\$" "$0" | cut -d':' -f1)"
  prefix="$0:$lineno [in ${FUNCNAME[0]}()] "
  expected="The color code 256 is not supported, provide between 0-255"
  run printcolln 256 "text"
  [ $status = 1 ]
  [ "$output" = "$prefix$expected" ]

  # not an integar
  lineno="$(grep -n "run printcolln red \"red text\"\$" "$0" | cut -d':' -f1)"
  prefix="$0:$lineno [in ${FUNCNAME[0]}()] "
  expected="Provide an integar as the first argument instead of 'red'"
  run printcolln red "red text"
  [ $status = 1 ]
  [ "$output" = "$prefix$expected" ]
}

testcase_printcolln() {
  describe "printcolln should print a line in a specified color"

  local color
  local reset
  local expected
  reset="$(tput sgr0)"

  # red
  color="$(tput setaf 1)"
  expected="this is red"
  run printcolln 1 "$expected"
  [ "$output" = "$color$expected$reset" ]

  # bright red
  color="$(tput setaf 9)"
  expected="this is bright red"
  run printcolln 9 "$expected"
  [ "$output" = "$color$expected$reset" ]
}

testcase_endswith_return_0() {
  describe "should return 0 if the word ends with the suffix"

  endswith "angry" "y"
  endswith "angry" "ry"
  endswith "angry" "gry"
}

testcase_endswith_return_1() {
  describe "should return 1 if the word does not end with the suffix"

  run endswith "angry" "x"
  [ "$status" -eq 1 ]
  run endswith "angry" "gryx"
  [ "$status" -eq 1 ]
}

testcase_pluralize_regular() {
  describe "should pluralize a regular noun based on its count"

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
  describe "should add -es to the end if the the noun ends in -s"

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


### Testing of methods in `unittest.sh`.

# The unit testing framework `unittest.sh` uses global variables whose
# prefixes commonly starts with `unittest`. Since this script aims to
# test methods in `unittest.sh` under the control of `unittest.sh`
# itself, either modifying or resetting the variables may cause a
# break of the testing framework. To prevent from going out of order,
# each global varialbe is stored in another prior to running each test
# case, and restore it to the original.
setup() {
  copy_array unittest_all_tests reserved_all_tests
  copy_array unittest_all_descriptions reserved_all_descriptions
  copy_array unittest_specified_tests reserved_specified_tests
  copy_array unittest_tests_to_run reserved_tests_to_run
  copy_array unittest_executed_tests reserved_executed_tests
  copy_array unittest_passed_tests reserved_passed_tests
  copy_array unittest_failed_tests reserved_failed_tests
  copy_array unittest_skipped_tests reserved_skipped_tests
}

teardown() {
  copy_array reserved_all_tests unittest_all_tests
  copy_array reserved_all_descriptions unittest_all_descriptions
  copy_array reserved_specified_tests unittest_specified_tests
  copy_array reserved_tests_to_run unittest_tests_to_run
  copy_array reserved_executed_tests unittest_executed_tests
  copy_array reserved_passed_tests unittest_passed_tests
  copy_array reserved_failed_tests unittest_failed_tests
  copy_array reserved_skipped_tests unittest_skipped_tests
}

mock_send_err() {
  return 123
}

testcase_errtrap() {
  describe "errtrap should trigger failed flag when ERR is sent"

  local lineno
  lineno="$(grep -ne "^  mock_send_err\$" "$0" | cut -d':' -f1)"

  mock_send_err
  [ "$unittest_failed" = true ]
  [ "${unittest_err_source[0]}" = "$0" ]
  [ "${unittest_err_lineno[0]}" = "$lineno" ]
  [ "${unittest_err_status[0]}" = "123" ]
  unittest_failed=false
}

testcase_initialize() {
  describe "initialize should initialize variables used throughout running tests"

  # Given that fake values are assigned,
  unittest_all_tests=("testcase_dummy")
  unittest_all_descriptions=("this is a dummy test")
  unittest_specified_tests=("testcase_dummy")
  unittest_tests_to_run=("testcase_dummy")
  unittest_executed_tests=("testcase_dummy")
  unittest_passed_tests=("testcase_dummy")
  unittest_failed_tests=("testcase_dummy")
  unittest_skipped_tests=("testcase_dummy")
  unittest_flag_help=true
  unittest_flag_list=true
  unittest_flag_force=true
  unittest_flag_in_run=true
  # When the function is called,
  unittest_initialize
  # Then they are initialized.
  [ ${#unittest_all_tests[@]} -eq 0 ]
  [ ${#unittest_all_descriptions[@]} -eq 0 ]
  [ ${#unittest_specified_tests[@]} -eq 0 ]
  [ ${#unittest_tests_to_run[@]} -eq 0 ]
  [ ${#unittest_executed_tests[@]} -eq 0 ]
  [ ${#unittest_passed_tests[@]} -eq 0 ]
  [ ${#unittest_failed_tests[@]} -eq 0 ]
  [ ${#unittest_skipped_tests[@]} -eq 0 ]
  [ $unittest_flag_help = false ]
  [ $unittest_flag_list = false ]
  [ $unittest_flag_force = false ]
  [ $unittest_flag_in_run = false ]
}

testcase_setup() {
  describe "should reset variables to their defaults"
  reserved_description=$unittest_description

  # Given that fake values are assigned,
  unittest_description="testcase_dummy"
  unittest_skip_note="skip the dummy test"
  unittest_failed=true
  unittest_skipped=true
  unittest_err_source=("test_unittest.sh")
  unittest_err_lineno=("105")
  unittest_err_status=("1")
  status=1234
  output="hoge"
  lines=("hoge" "fuga" "foo")
  # When the variables are reset,
  unittest_setup
  # Then they are set to their defaults.
  [ -z $unittest_description ]
  [ -z $unittest_skip_note ]
  [ $unittest_failed = false ]
  [ $unittest_skipped = false ]
  [ ${#unittest_err_source[@]} -eq 0 ]
  [ ${#unittest_err_lineno[@]} -eq 0 ]
  [ ${#unittest_err_status[@]} -eq 0 ]
  [ $status -eq 0 ]
  [ -z $output ]
  [ ${#lines[@]} -eq 0 ]

  unittest_description=$reserved_description
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
  describe "should do nothing for a test which is not skipped"

  # Given that a test case definition which is not going to be skipped,
  local test_def1="$(declare -f mock_not_skip)"
  # When the test case should not be skipped,
  _unittest_handle_skipped_test "mock_not_skip"
  # Then do nothing.
  local test_def2="$(declare -f mock_not_skip)"
  [ "$test_def1" = "$test_def2" ]
}

testcase_handle_skipped_test() {
  describe "should handle a skipped test"

  # Given that a test case definition which is going to be skipped,
  # When the test case should be skipped,
  _unittest_handle_skipped_test "mock_skip"
  # Then add `return 0` shortly after the `skip` command.
  local test_def1="$(declare -f mock_skip | sed '1d')"
  local test_def2="$(declare -f mock_skip_handled | sed '1d')"
  [ "$test_def1" = "$test_def2" ]
}

testcase_categorize_by_result_passed() {
  describe "should categorize a test into an appropriate group if it's passed"

  # Given that the test case is passed,
  unittest_skipped=false
  unittest_failed=false
  local testcase="testcase_dummy"
  unittest_executed_tests=()
  unittest_passed_tests=()
  unittest_failed_tests=()
  unittest_skipped_tests=()
  # When the function is executed,
  _unittest_categorize_by_result "$testcase"
  # Then the function is categorized into passed.
  [ "${unittest_executed_tests[0]}" = "$testcase" ]
  [ "${unittest_passed_tests[0]}" = "$testcase" ]
  [ ${#unittest_failed_tests[@]} -eq 0 ]
  [ ${#unittest_skipped_tests[@]} -eq 0 ]
}

testcase_categorize_by_result_failed() {
  describe "should categorize a test into an appropriate group if it's failed"

  # Given that the test case is passed,
  unittest_skipped=false
  unittest_failed=true
  local testcase="testcase_dummy"
  unittest_executed_tests=()
  unittest_passed_tests=()
  unittest_failed_tests=()
  unittest_skipped_tests=()
  # When the function is executed,
  _unittest_categorize_by_result "$testcase"
  # Then the function is categorized into passed.
  [ "${unittest_executed_tests[0]}" = "$testcase" ]
  [ ${#unittest_passed_tests[@]} -eq 0 ]
  [ "${unittest_failed_tests[0]}" = "$testcase" ]
  [ ${#unittest_skipped_tests[@]} -eq 0 ]

  if ((${#unittest_err_status[@]} == 0)); then
    unittest_failed=false
  fi
}

testcase_categorize_by_result_skipped() {
  describe "should categorize a test into an appropriate group if it's skipped"

  # Given that the test case is passed,
  unittest_skipped=true
  unittest_failed=false
  local testcase="testcase_dummy"
  unittest_executed_tests=()
  unittest_passed_tests=()
  unittest_failed_tests=()
  unittest_skipped_tests=()
  # When the function is executed,
  _unittest_categorize_by_result "$testcase"
  # Then the function is categorized into passed.
  [ "${unittest_executed_tests[0]}" = "$testcase" ]
  [ ${#unittest_passed_tests[@]} -eq 0 ]
  [ ${#unittest_failed_tests[@]} -eq 0 ]
  [ "${unittest_skipped_tests[0]}" = "$testcase" ]

  unittest_skipped=false
}

testcase_describe() {
  local _desc="should store the description of the test case"
  [ "$(_unittest_describe)" = "testcase_describe" ]

  describe "$_desc"
  [ "$(_unittest_describe)" = "$_desc" ]

  describe
  [ "$(_unittest_describe)" = "testcase_describe" ]

  describe should store the description of the test case
  [ "$(_unittest_describe)" = "$_desc" ]
}

foo() {
  return 10
}

testcase_run_return_0() {
  describe "should always return 0"
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
  describe "should capture status code returned by command with run"

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
  describe "should capture output from arguments provided with the run command"

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
  describe "should capture output from arguments provided with the run line by line"

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
  describe "should make run throw an error when command not found"

  local _status
  run hoge 2>/dev/null
  _status=$?
  unittest_failed=false
  [ $_status -ne 0 ]
}

testcase_print_result_pass() {
  describe "should print the result for a passed test case"

  run _unittest_print_result_pass
  [ "${lines[0]}" = " ✓ should print the result for a passed test case" ]
}

testcase_print_result_fail() {
  describe "should print the result for a failed test case"

  local lineno
  lineno="$(grep -ne "^  false # should.*number" "$0" | cut -d':' -f1)"

  false # should appear this line number
  unittest_failed=false
  run _unittest_print_result_fail
  [ "${lines[0]}" = "$(tput setaf 1) ✗ should print the result for a failed test case$(tput sgr0)" ]
  [ "${lines[1]}" = "$(tput setaf 9)   (in test file ./test_unittest.sh, line $lineno)$(tput sgr0)" ]
  [ "${lines[2]}" = "$(tput setaf 9)     \`false # should appear this line number' failed with 1$(tput sgr0)" ]
}

testcase_print_result_skip() {
  describe "should print the result for a skipped test case"

  run _unittest_print_result_skip
  [ "${lines[0]}" = " - should print the result for a skipped test case (skipped)" ]

  unittest_skip_note="this is skipped"
  run _unittest_print_result_skip
  [ "${lines[0]}" =\
    " - should print the result for a skipped test case (skipped: this is skipped)" ]
}

_testcase_parse_flags_setup() {
  unittest_initialize
  [ "$unittest_flag_help" = false ]
  [ "$unittest_flag_list" = false ]
  [ "$unittest_flag_force" = false ]
}

testcase_parse_flags_help() {
  describe "should set flags to show help message"

  _testcase_parse_flags_setup
  unittest_parse -h
  [ "$unittest_flag_help" = true ]

  _testcase_parse_flags_setup
  unittest_parse --help
  [ "$unittest_flag_help" = true ]
}

testcase_parse_flags_list() {
  describe "should set flags to list available tests"

  _testcase_parse_flags_setup
  unittest_parse -l
  [ "$unittest_flag_list" = true ]

  _testcase_parse_flags_setup
  unittest_parse --list-tests
  [ "$unittest_flag_list" = true ]
}

testcase_parse_flags_force() {
  describe "should set flags to force to run skipping tests"

  _testcase_parse_flags_setup
  unittest_parse -f
  [ "$unittest_flag_force" = true ]

  _testcase_parse_flags_setup
  unittest_parse --force-run
  [ "$unittest_flag_force" = true ]
}

testcase_parse_flags_unsupported() {
  describe "should throw an error if unsupported option is supplied"

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
  describe "should store positional arguments to a variable"

  unittest_parse "should test something" "should check an awesome thing"
  [ "${unittest_specified_tests[0]}" = "should test something" ]
  [ "${unittest_specified_tests[1]}" = "should check an awesome thing" ]

  unittest_parse -f "test 01" "test 02"
  [ "$unittest_flag_force" = true ]
  [ "${unittest_specified_tests[0]}" = "test 01" ]
  [ "${unittest_specified_tests[1]}" = "test 02" ]
}

testcase_collect_testcases_check_num() {
  describe "should check the number of collected testcases"

  local n_testcases
  n_testcases="$(grep -e "^testcase_.*() {$" "$0" | wc -l)"

  [ "${#unittest_all_tests[@]}" = "$n_testcases" ]
  [ "${#unittest_all_descriptions[@]}" = "$n_testcases" ]
}

testcase_collect_testcases_dummy01() {
  describe "this is a dummy test"
}

testcase_collect_testcases_dummy02() {
  describe 'this is a dummy test which has a so so so so loooooooooong description'\
           'that it does not fit into one line'
}

testcase_collect_testcases_dummy03() {
  describe ""
}

testcase_collect_testcases_dummy04() {
  describe
}

testcase_collect_testcases_dummy05() {
  :
}

# testcase_collect_testcases_check_map() {
#   describe "should check if the created map stores keys and values correctly"

#   local key="this is a dummy test"
#   [ "${unittest_all_tests_map[$key]}" = "testcase_collect_testcases_dummy01" ]

#   key='this is a dummy test which has a so so so so loooooooooong description that it does not fit into one line'
#   [ "${unittest_all_tests_map[$key]}" = "testcase_collect_testcases_dummy02" ]

#   # When no description is provided, the key should be its function name
#   key="testcase_collect_testcases_dummy03"
#   [ "${unittest_all_tests_map[$key]}" = "$key" ]

#   key="testcase_collect_testcases_dummy04"
#   [ "${unittest_all_tests_map[$key]}" = "$key" ]

#   key="testcase_collect_testcases_dummy05"
#   [ "${unittest_all_tests_map[$key]}" = "$key" ]
# }

unittest_main "$@"
