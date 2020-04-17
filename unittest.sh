#!/usr/bin/env bash

# unittest.sh
#
# This script provides a micro unit testing framework for bash shell
# scripts. Each test case consists of a short description of it and
# shell commands to be tested. Note that this framework does not
# provide any assertion command. Instead, it harnesses a trap on `ERR`
# signal, which enabled with the `errtrace` option by the `set`
# command provided by bash. If every command in a test case exits with
# the `0` status code, it means that the test passes.
#
# The following code is an example usage of this framework.
#
# --
# #!/usr/bin/env bash
#
# source unittest.sh
#
# testcase_add() {
#   it "adds numbers using bc"
#   result="$(echo 2+2 | bc)"
#   [ "$result" -eq 4 ]
# }
#
# testcase_run() {
#   it "gets the word 'bar' with cut command"
#   run echo 'foo bar baz' | cut -d' ' -f2
#   [ "$status" -eq 0 ]
#   [ "$output" = "bar" ]
# }
#
# testcase_skip() {
#   it "is skipped"
#   skip "foo command returns 0 but not now"
#   run foo
#   [ "$status" -eq 0 ]
# }
#
# testcase_fail() {
#   it "always fails"
#   false
# }
#
# unittest_run "$@"
# ..
#
# Let's say the example script is saved as `test_example.sh`. Execute
# the script as a standard bash script, then the output on the
# terminal looks like this.
#
# --
# $ ./test_example.sh
#  ✓ adds numbers using bc
#  ✗ always fails
#    (in test file ./test_example.sh, line 27)
#      `false' failed with 1
#  ✓ gets the word 'bar' with cut command
#  - is skipped (skipped: foo command return 0 but not now)
#
# 4 tests, 1 failure, 1 skipped
# ..
#
# The order to execute test cases is sorted alphabetically. Each test
# case is defined as a function whose name starts with `testcase_`.
# Inside the test case a short description of the test should be put
# in the first line with the `it` helper command. Afterwards, standard
# shell commands can be written. If every command exits with the `0`
# status, the test passes.
#
# The hepler command `run` invokes arguments as a bash command, then
# stores its exit status in a variable `$status`. The `run` command
# itself exits with `0` status code so that you can continue following
# asssertions. Also, the `$output` variable contains the contents of
# the standard output and the standard errors.
#
# To skip some test temporarily, you can use the `skip` command. The
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
# and `$status` and `$output` variables and so on are adopted from the
# Bash Automated Testing System (a.k.a BATS), which is hosted on
# [https://github.com/sstephenson/bats] by Sam Stephenson and
# currently-maintained version on
# [https://github.com/bats-core/bats-core] by bats-core contributors.
# I reimplemented almost the same functionality, but do not express
# their copyrights explicitly. I would like to thank them here.


### Setting shell options.

# Treat unset variables and parameters as an error.
set -u

# Set an option so that any trap on ERR signal is caught to turn
# `_unittest_failed` flag on. This is the same as `set -E`. Note that
# `set -o errexit` or `set -e` can not be used here since that option
# exits immediately when ERR is sent.
set -o errtrace
trap _unittest_errtrap ERR


### Global variables used throughout running the all test cases.

# Contains a filename of the test script.
_unittest_script_filename="${BASH_SOURCE[1]}"

# Contains the working directory to run test cases. Its default value
# is the current working directory, but it may be modified with
# command arguments.
_unittest_working_directory="$(pwd)"


### Global variables which store executed tests and their results.

# An array which contains all the function names defined in the test
# script. It is built by the `unittest_collect_testcases` function.
_unittest_all_tests=()

# An associative array which contains test case functions as values
# indexed by descriptions of the test. It is built by the
# `unittest_collect_testcases` function
declare -A _unittest_tests_map

# An array which contains function names actually executed.
_unittest_executed_tests=()

# An array which contains function names of passed test cases.
_unittest_passed_tests=()

# An array which contains function names of failed test cases.
_unittest_failed_tests=()

# An array which contains function names of skipped test cases.
_unittest_skipped_tests=()


### Global variables cleared or initialized prior to running each test
### case.

# Contains a function which is about to run (or currently running) as
# a test case. Its value should start with 'testcase_' so as to be
# collected automatically by `unittest_collect_testcases`.
_unittest_testcase=

# Contains a string which describes the current test case. It is given
# by the `it` command.
_unittest_description=

# Contains notes why a test case is skipped. It is given as an
# optional argument of the `skip` command.
_unittest_skip_note=

# Keeps the state whether a test case is failed or not. When it is set
# to `true`, it means the most recent test case failed.
_unittest_failed=false

# When a test case is skipped, this flag is set to `true`.
_unittest_skipped=false

# An array which contains source filenames corresponding to functions
# being executed when ERR signal is trapped.
_unittest_err_source=()

# An array which contains line numbers in source files corresponding
# to functions being executed when ERR signal is trapped.
_unittest_err_lineno=()

# An array which contains statuses returned from functions when ERR
# signal is trapped.
_unittest_err_status=()


### Global variables used in test scripts.

# Contains an exit status when running a bash command with the `run`
# command.
export status
status=0

# Contains a string combined the standard output and the standard
# error of a bash command executed with the `run` command.
export output
output=

# An array whose elements are separated lines of the content of the
# `$output` variable.
export lines
lines=()


### Internal helper functions

######################################################################
# Initialize global variables listed below which are used throughout
# running all tests.
# Globals:
#   _unittest_all_tests
#   _unittest_tests_map
#   _unittest_executed_tests
#   _unittest_passed_tests
#   _unittest_failed_tests
#   _unittest_skipped_tests
# Arguments:
#   None
######################################################################
_unittest_initialize() {
  _unittest_all_tests=()
  # unset -v _unittest_tests_map
  # declare -A _unittest_tests_map
  _unittest_executed_tests=()
  _unittest_passed_tests=()
  _unittest_failed_tests=()
  _unittest_skipped_tests=()
}

######################################################################
# Executed when ERR signal is caught. Turn the failed flag on and
# store the source file, the location and the status code where the
# ERR signal has been sent.
# Globals:
#   _unittest_failed
#   _unittest_err_source
#   _unittest_err_lineno
#   _unittest_err_status
# Arguments:
#   None
######################################################################
_unittest_errtrap() {
  # Keep the exit status returned by the last function or command.
  local _status="$?"

  # Check if ERR signal is sent from the test script.
  if [[ "${BASH_SOURCE[1]}" = "$_unittest_script_filename" ]]; then
    _unittest_failed=true
    _unittest_err_source+=("${BASH_SOURCE[1]}")
    _unittest_err_lineno+=("${BASH_LINENO[0]}")
    _unittest_err_status+=("$_status")
  fi
}

######################################################################
# Reset variables which store the result and attributes of each test
# to their default values. This function should be executed prior to
# running each test.
# Globals:
#   _unittest_description
#   _unittest_skip_note
#   _unittest_failed
#   _unittest_skipped
#   _unittest_err_source
#   _unittest_err_lineno
#   _unittest_err_status
# Arguments:
#   None
######################################################################
_unittest_reset_vars() {
  _unittest_description=
  _unittest_skip_note=
  _unittest_failed=false
  _unittest_skipped=false
  _unittest_err_source=()
  _unittest_err_lineno=()
  _unittest_err_status=()
  status=0
  output=
  lines=()
}

######################################################################
# To achieve the skip functionality, skim the current test case and
# add a statement `return 0` shortly following the `skip` command if
# it exisis.
# Globals:
#   None
# Arguments:
#   Test case to be handled, a function name
######################################################################
_unittest_handle_skipped_test() {
  local testcase="$1"
  local definition="$(declare -f "$testcase")"
  local new_definition=

  # replace `skip` with `skip; return 0;`
  if echo "$definition" | grep -q "^[[:space:]]\+skip"; then
    local cmd
    cmd="s/^\([[:space:]]\+\)skip\(.*\);/\1skip\2;\n\1return 0;/"
    new_definition="$(echo "$definition" | sed -e "$cmd")"
    eval "$new_definition"
  fi
}

######################################################################
# Execute pre-processing stuff before running each test.
# Globals:
#   _unittest_testcase
# Arguments:
#   Test case to run, a function name.
######################################################################
_unittest_preprocesses() {
  # set the function name of the current test case
  _unittest_testcase="$1"
  # reset variables
  _unittest_reset_vars
  # handle a skipped test
  _unittest_handle_skipped_test "$_unittest_testcase"
}

######################################################################
# Categorize an executed test case into one of the groups, passed,
# failed or skipped.
# Gloabls:
#   _unittest_failed
#   _unittest_skipped
#   _unittest_passed_tests
#   _unittest_failed_tests
#   _unittest_skipped_tests
# Arguments:
#   Test case to run, a function name
######################################################################
_unittest_categorize_by_result() {
  local testcase="$1"

  _unittest_executed_tests+=("$testcase")
  if [[ $_unittest_skipped = true ]]; then
    _unittest_skipped_tests+=("$testcase")
  elif [[ $_unittest_failed = true ]]; then
    _unittest_failed_tests+=("$testcase")
  else
    _unittest_passed_tests+=("$testcase")
  fi
}

######################################################################
# Execute post-processing stuff after running each test.
# Globals:
#   _unittest_skipped_tests
#   _unittest_failed_tests
#   _unittest_passed_tests
# Arguments:
#   Test case to run, a function name
######################################################################
_unittest_postprocesses() {
  local testcase="$1"
  _unittest_categorize_by_result "$testcase"
}

# define colors of faces for printing results.
reset=$(tput sgr0)
red=$(tput setaf 1)
brightred=$(tput setaf 9)

_unittest_print_result_pass() {
  printf " ✓ %s\n" "$_unittest_description"
}

_unittest_print_result_fail() {
  local source lineno
  local failure_location failure_detail

  printf "%s ✗ %s%s\n" "$red" "$_unittest_description" "$reset"
  for i in "${!_unittest_err_status[@]}"; do
    source="${_unittest_err_source[$i]}"
    lineno="${_unittest_err_lineno[$i]}"
    failure_location="$(printf "test file %s, line %d" "$source" "$lineno")"
    failure_detail="$(sed -e "${lineno}q;d" "$source" | sed -e "s/^[[:space:]]*//")"
    printf "%s   (in %s)\n     \`%s\' failed with %d%s\n"\
           "$brightred" "$failure_location" "$failure_detail" \
           "${_unittest_err_status[$i]}" "$reset"
  done
}

_unittest_print_result_skip() {
  local skip_note
  skip_note="${_unittest_skip_note:+: }${_unittest_skip_note}"
  printf " - %s (skipped%s)\n" "$_unittest_description" "$skip_note"
}

_unittest_print_result() {
  if [[ $_unittest_skipped = true ]]; then
    _unittest_print_result_skip
  elif [[ $_unittest_failed = true ]]; then
    _unittest_print_result_fail
  else
    _unittest_print_result_pass
  fi
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


### Core functions

unittest_setup() {
  _unittest_initialize
}

unittest_collect_testcases() {
  local regex_tests
  regex_tests="^testcase_.*"

  while IFS= read -r func; do
    _unittest_all_tests+=("$func")
  done < <(declare -F | cut -d' ' -f3 | grep -e "$regex_tests")
}

unittest_run_testcases() {
  local testcase

  for testcase in "${_unittest_all_tests[@]}"; do
    _unittest_preprocesses "$testcase"
    setup
    $_unittest_testcase
    teardown
    _unittest_postprocesses "$testcase"
    _unittest_print_result
  done
}

unittest_print_summary() {
  local n_tests n_failed n_skipped
  local summary

  # store numbers of executed tests in variables
  n_tests=${#_unittest_all_tests[@]}
  n_failed=${#_unittest_failed_tests[@]}
  n_skipped=${#_unittest_skipped_tests[@]}

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


### Helper commands

######################################################################
# `setup` and `teardown` commands allow you to define a series of
# commands that will be executed before and after each test case,
# respectively. These are supposed to be overwitten in user's test
# script.
# Globals:
#   None
# Arguments:
#   None
######################################################################
setup() {
  :
}

teardown() {
  :
}

######################################################################
# `it` command allows you to give a short description of each test
# case to the test runner
# Globals:
#   _unjittest_description
# Arguments:
#   Description of test case, string
######################################################################
it() {
  _unittest_description="${1:-anonymous test}"
}

######################################################################
# `run` command allows you to invoke arguments as a bash command, then
# store its exit status in a variable `$status`. The `run` command
# exits with `0` status so that you can continue following assertions.
# Also, the `$output` variable contains the contents of the standard
# output and the standard error.
# Globals:
#   status
#   output
#   lines
# Arguments:
#   Command and its arguments
######################################################################
run() {
  if (( $# == 0 )); then
    return 0
  fi
  local cmd="$1"; shift
  output="$($cmd "$@" 2>&1)"
  status=$?
  mapfile -t lines < <(echo "$output")
  return 0
}

######################################################################
# `skip` command allows you to skip a test case inside which it is
# executed. It accepts the reason for skipping as an additional
# argument.
# Globals:
#   _unittest_skip_note
#   _unittest_skipped
# Arguments:
#   Reason for skipping, string (optional)
######################################################################
skip() {
  _unittest_skip_note="${1:-}"
  _unittest_skipped=true
}

######################################################################
# Perform the primary test runner. This carries out the initial setup,
# the decision of test cases, the execution of them and the printing
# of the result, sequentially.
# Globals:
#   None
# Arguments:
#   None
######################################################################
unittest_run() {
  unittest_setup
  unittest_collect_testcases
  unittest_run_testcases
  unittest_print_summary
}
