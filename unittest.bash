#!/usr/bin/env bash

# unittest.bash
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
# source unittest.bash
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
# Let's say the example script is saved as `test_example.bash`.
# Execute the script as a standard bash script, then the output on the
# terminal looks like this.
#
# --
# $ ./test_example.bash
#  ✓ adds numbers using bc
#  ✗ always fails
#    (in test file ./test_example.bash, line 27)
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
# in the first line with the `this_test` helper command. Afterwards,
# standard shell commands can be written. If every command exits with
# the `0` status, the test passes.
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


### Global variables used throughout running the all test cases.

# Contains a filename of the test script.
__unittest_script_filename="${BASH_SOURCE[1]}"

# Contains the working directory to run test cases. Its default value
# is the current working directory, but it may be modified with
# command arguments.
__unittest_working_directory="$(pwd)"


### Global variables which store executed tests and their results.

# An array which contains all the function names defined in the test
# script. It is built by the `unittest_collect_testcases` function.
__unittest_all_tests=()

# An associative array which contains test case functions as values
# indexed by descriptions of the test. It is built by the
# `unittest_collect_testcases` function
declare -A __unittest_tests_map

# An array which contains function names actually executed.
__unittest_executed_tests=()

# An array which contains function names of passed test cases.
__unittest_passed_tests=()

# An array which contains function names of failed test cases.
__unittest_failed_tests=()

# An array which contains function names of skipped test cases.
__unittest_skipped_tests=()


### Global variables cleared or initialized prior to running each test
### case.

# Contains a function which is about to run (or currently running) as
# a test case. Its value should start with 'testcase_' so as to be
# collected automatically by `unittest_collect_testcases`.
__unittest_testcase=

# Contains the definition of the function `$__unittest_testcase`. If
# the `skip` command exists inside it, a statement `return 0;` is
# added to just below the `skip` command while running pre-process.
__unittest_testcase_definition=

# Contains a string which describes the current test case. It is given
# by the `this_test` command.
__unittest_description=

# Contains notes why a test case is skipped. It is given as an
# optional argument of the `skip` command.
__unittest_skip_note=

# Keeps the state whether a test case is failed or not. When it is set
# to `true`, it means the most recent test case failed.
__unittest_failed=false

# When a test case is skipped, this flag is set to `true`.
__unittest_skipped=false

# An array which contains source filenames corresponding to functions
# being executed when ERR signal is trapped.
__unittest_err_source=()

# An array which contains line numbers in source files corresponding
# to functions being executed when ERR signal is trapped.
__unittest_err_lineno=()

# An array which contains statuses returned from functions when ERR
# signal is trapped.
__unittest_err_status=()


### Setting the `errtrace` option to catch ERR signal

# Set an option so that any trap on ERR signal is caught to turn
# `__unittest_failed` flag on. This is the same as `set -E`. Note that
# `set -o errexit` or `set -e` can not be used here since that option
# exits immediately when ERR is sent.
set -o errtrace
trap __unittest_on_failed ERR

this_test() {
  __unittest_description="${1:-anonymous test}"
}

run() {
  :
}

skip() {
  __unittest_skip_note="${1:-}"
  __unittest_skipped=true
}

unittest_setup() {
  :
}

#
__unittest_on_failed() {
  # Keep the exit status returned by the last function or command.
  local _status="$?"

  # Check if ERR signal is sent from the test script.
  if [[ "${BASH_SOURCE[1]}" = "$__unittest_script_filename" ]]; then
    __unittest_failed=true
    __unittest_err_source+=("${BASH_SOURCE[1]}")
    __unittest_err_lineno+=("${BASH_LINENO[0]}")
    __unittest_err_status+=("$_status")
  fi
}

__unittest_preprocesses() {
  __unittest_testcase="$1"

  local definition
  definition="$(declare -f "$__unittest_testcase")"

  # initialize variables
  __unittest_description=
  __unittest_failed=false
  __unittest_skipped=false
  __unittest_err_source=()
  __unittest_err_lineno=()
  __unittest_err_status=()

  # pre-process for a skipped test
  if echo "$definition" | grep -q "^[[:space:]]\+skip"; then
    local cmd
    cmd="s/^\([[:space:]]\+\)skip\(.*\);/\1skip\2;\n\1return 0;/"
    __unittest_testcase_definition="$(echo "$definition" | sed -e "$cmd")"
    eval "$__unittest_testcase_definition"
  fi
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

# define colors of faces for printing results.
reset=$(tput sgr0)
red=$(tput setaf 1)
brightred=$(tput setaf 9)

__unittest_print_result_pass() {
  printf " ✓ %s\n" "$__unittest_description"
}

__unittest_print_result_fail() {
  local source lineno
  local failure_location failure_detail

  printf "%s ✗ %s%s\n" "$red" "$__unittest_description" "$reset"
  for i in "${!__unittest_err_status[@]}"; do
    source="${__unittest_err_source[$i]}"
    lineno="${__unittest_err_lineno[$i]}"
    failure_location="$(printf "test file %s, line %d" "$source" "$lineno")"
    failure_detail="$(sed -e "${lineno}q;d" "$source" | sed -e "s/^[[:space:]]*//")"
    printf "%s   (in %s)\n     \`%s\' failed with %d%s\n"\
           "$brightred" "$failure_location" "$failure_detail" \
           "${__unittest_err_status[$i]}" "$reset"
  done
}

__unittest_print_result_skip() {
  local skip_note
  skip_note="${__unittest_skip_note:+: }${__unittest_skip_note}"
  printf " - %s (skipped%s)\n" "$__unittest_description" "$skip_note"
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
    __unittest_all_tests+=("$func")
  done < <(declare -F | cut -d' ' -f3 | grep -e "$regex_tests")
}

unittest_run_testcases() {
  local testcase

  for testcase in "${__unittest_all_tests[@]}"; do
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
  n_tests=${#__unittest_all_tests[@]}
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
