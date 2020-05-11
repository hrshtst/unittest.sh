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
# unittest_main "$@"
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
# Finally, a `unittest_main` command should be put with command line
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

# An array which contains all the descriptions provided by the user
# for the test cases.
_unittest_all_descriptions=()

# An array which contains specified test cases by the user.
_unittest_specified_tests=()

# An array which contains function names to run.
_unittest_tests_to_run=()

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


### Flags to control behavior based on the command line arguments.

# Flag to show help message and exit.
_unittest_flag_help=false

# Flag to show the list available tests and exit.
_unittest_flag_list=false

# Flag to run skipping test forcely.
_unittest_flag_force=false


### Internal helper functions

######################################################################
# Output an error message to the standard error.
# Globals:
#   None
# Arguments:
#   An error message, a string
######################################################################
error() {
  echo "$*" >&2
}

######################################################################
# Initialize global variables listed below which are used throughout
# running all tests.
# Globals:
#   _unittest_all_tests
#   _unittest_all_descriptions
#   _unittest_specified_tests
#   _unittest_tests_to_run
#   _unittest_executed_tests
#   _unittest_passed_tests
#   _unittest_failed_tests
#   _unittest_skipped_tests
#   _unittest_flag_help
#   _unittest_flag_list
#   _unittest_flag_force
# Arguments:
#   None
######################################################################
_unittest_initialize() {
  _unittest_all_tests=()
  _unittest_all_descriptions=()
  _unittest_specified_tests=()
  _unittest_tests_to_run=()
  _unittest_executed_tests=()
  _unittest_passed_tests=()
  _unittest_failed_tests=()
  _unittest_skipped_tests=()
  _unittest_flag_help=false
  _unittest_flag_list=false
  _unittest_flag_force=false
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
# Extract a description from a definition of a test case function. If
# no description is provided or it is invalid, returns its test case
# function name.
# Globals:
#   None
# Arguments:
#   A test case function, a string.
# Outputs:
#   A string which is provided as a description or the function name
#   to the standard output.
######################################################################
_unittest_extract_description() {
  local _func="$1"
  local regex_find_it="^[[:space:]]\+it.*"
  local sed_remove_quote="s/[\"';]//g"
  local sed_find_desc="s/^[[:space:]]\+it \(.*\)/\1/p"
  local _line=
  local _desc=

  # Find lines which contains `it` at the beginning.
  _line="$(declare -f "$_func" | grep -e "$regex_find_it")"
  # Choose only the last one.
  _line="$(echo "$_line" | tail -1)"
  # Extract the description
  _desc="$(echo "$_line" | sed -e "$sed_remove_quote" | sed -n "$sed_find_desc")"

  # Output to the standard output.
  if [[ -n "$_desc" ]]; then
    echo "$_desc"
  else
    echo "$_func"
  fi
}

######################################################################
# Return the index of the array `_unittest_all_descriptions` whose
# value is the supplied description.
# Globals:
#   _unittest_all_descriptions
# Arguments:
#   Description of a test case, a string.
# Outputs:
#   The index or a null character to the standard output.
######################################################################
_unittest_get_index_from_description() {
  if (( $# == 0 )); then
    error "No descriptions provided"
  fi

  local desc="$1"
  local index=
  local found=false
  for index in "${!_unittest_all_descriptions[@]}"; do
    if [[ "$desc" == "${_unittest_all_descriptions[$index]}" ]]; then
      found=true
    fi
  done
  [[ "$found" == true  ]] && echo "$index"
}

######################################################################
# Collects functions whose names begin with `testcase_` and their
# descriptions provided by the user. Function names and descriptions
# are stored in global variables `_unittest_all_tests` and
# `_unittest_all_descriptions`, respectively.
# Globals:
#   _unittest_all_tests
#   _unittest_all_descriptions
# Arguments:
#   None
######################################################################
_unittest_collect_testcases() {
  local regex_find_testcase="^testcase_.*"
  local _func=
  local _desc=

  while IFS= read -r _func; do
    _desc="$(_unittest_extract_description "$_func")"
    _unittest_all_tests+=("$_func")
    _unittest_all_descriptions+=("$_desc")
  done < <(declare -F | cut -d' ' -f3 | grep -e "$regex_find_testcase")
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
# Shows the description of the current test case. If no description
# provided, just its function name will be shown.
# Globals:
#   _unittest_description
# Arguments:
#   None.
# Outputs:
#   Writes its description to stdout.
######################################################################
_unittest_describe() {
  if [[ -z "$_unittest_description" ]]; then
    echo "$_unittest_testcase"
  else
    echo "$_unittest_description"
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
  if [[ "$_unittest_flag_force" = false ]]; then
    # handle a skipped test
    _unittest_handle_skipped_test "$_unittest_testcase"
  fi
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
  printf " ✓ %s\n" "$(_unittest_describe)"
}

_unittest_print_result_fail() {
  local source lineno
  local failure_location failure_detail

  printf "%s ✗ %s%s\n" "$red" "$(_unittest_describe)" "$reset"
  for i in "${!_unittest_err_status[@]}"; do
    source="${_unittest_err_source[$i]}"
    lineno="${_unittest_err_lineno[$i]}"
    failure_location="$(printf "test file %s, line %d" "$source" "$lineno")"
    failure_detail="$(sed -e "${lineno}q;d" "$source" | sed -e "s/^[[:space:]]*//")"
    printf "%s   (in %s)\n     \`%s' failed with %d%s\n"\
           "$brightred" "$failure_location" "$failure_detail" \
           "${_unittest_err_status[$i]}" "$reset"
  done
}

_unittest_print_result_skip() {
  local skip_note
  skip_note="${_unittest_skip_note:+: }${_unittest_skip_note}"
  printf " - %s (skipped%s)\n" "$(_unittest_describe)" "$skip_note"
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

######################################################################
# Return True if the string ends with the specified suffix, otherwise
# return False.
# Globals:
#   None
# Arguments:
#   A word, a string.
#   A suffix, a string.
# Returns:
#   0(True) if the word ends with the suffix.
#   1(False) otherwise.
######################################################################
endswith() {
  if (( $# != 2 )); then
    error "Function \`endswith' requires two positional arguments."
    return 1
  fi

  local word="$1"
  local suffix="$2"
  local regex="^.*${suffix}$"
  [[ "$word" =~ $regex ]] || return 1
  return 0
}

######################################################################
# Pluralize a word based on its count. When the count is omitted,
# always make the word plural. (Not implemented completely yet.)
# TODO:
#   Implement irregular cases.
# Globals:
#   None
# Arguments:
#   A singular word, a string.
#   The count of the word, a number.
# Outputs:
#   Writes pluralized or singular word to stdout.
######################################################################
pluralize() {
  local word="$1"
  local n="${2:-0}"

  if (( n == 1 )); then
    # Return a singular $word.
    echo "${word}"
    return 0
  fi

  # Make $word plural based on its suffix.
  if endswith "$word" "s"; then
    # Append -es as $word ends in s.
    echo "${word}es"
  else
    # Append -es as $word is a regular noun.
    echo "${word}s"
  fi
}


### Core functions

######################################################################
# Set up stuff to run tests.
# Globals:
#   None
# Arguments:
#   None
######################################################################
unittest_setup() {
  _unittest_initialize
}

######################################################################
# Show help message to the standard output.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Help message to the stdout.
######################################################################
unittest_help() {
  cat <<- EOT
Run unit tests defined in \`${_unittest_script_filename#./}' and print
the result of each test case and the summary.

Usage: $0 [-l] [-f] [-h] <test-spec> ...

<test-spec> ...     Specify which tests to run. Given no test specs
                    supplied all test cases are run.
-l, --list-tests    List available tests.
-f, --force-run     Force to run tests including skipping ones.
-h, --help          Print this message.

Notice for test specs:
Test specs must be enclosed in quotes if they contain spaces. They are
case insensitive. A wildcard charcter, namely *, can substitue for any
number of any characters.

EOT
}

######################################################################
# Show the list of available tests.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   List of available tests to stdout.
######################################################################
unittest_list_tests() {
  local index=
  local func=
  local desc=
  printf "%d tests found\n" "${#_unittest_all_tests[@]}"
  for index in "${!_unittest_all_tests[@]}"; do
    func="${_unittest_all_tests[$index]}"
    desc="${_unittest_all_descriptions[$index]}"
    printf "%2d: %s: %s\n" "$index" "$func" "$desc"
  done
}

######################################################################
# Parse command line arguments.
# Globals:
#   None
# Arguments:
#   Command line arguments
######################################################################
unittest_parse() {
  local testspecs=()
  local param=

  while (( $# )); do
    param="$1"
    case "$param" in
      -l|--list-tests)
        _unittest_flag_list=true
        shift
        ;;
      -f|--force-run)
        _unittest_flag_force=true
        shift
        ;;
      -h|--help)
        _unittest_flag_help=true
        shift
        ;;
      -*)
        error "$0: unsupported option: $param"
        return 1
        shift
        ;;
      *)
        testspecs+=("$param")
        shift
        ;;
    esac
  done

  set -- "${testspecs[@]}"
 _unittest_specified_tests=("${testspecs[@]}")
}

######################################################################
# Decide which testcases should be run.
# Globals:
#   None
# Arguments:
#   None
######################################################################
unittest_decide_testcases() {
  _unittest_collect_testcases
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
  summary+="$(printf "%d %s" $n_tests "$(pluralize test $n_tests)")"
  summary+="$(printf ", %d %s" $n_failed "$(pluralize failure $n_failed)")"
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
  _unittest_description="${*:-$_unittest_testcase}"
}

######################################################################
# `run` command allows you to invoke arguments as a bash command, then
# store its exit status in a variable `$status`. The `run` command
# exits with `0` status so that you can continue following assertions.
# Also, the `$output` variable contains the contents of the standard
# output and the standard error. If the given arguments cannot be
# found, it return non-zero value to make the test explicitly fail.
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
  local lineno="${BASH_LINENO[0]}"
  local source="${BASH_SOURCE[1]}"
  status=0
  output=
  lines=()
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf >&2 "%s: line %d: %s: command not found\n"\
               "$source" "$lineno" "$cmd"
    return 1
  else
    output="$($cmd "$@" 2>&1)"
    status=$?
    mapfile -t lines < <(echo "$output")
  fi
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
  [[ "$_unittest_flag_force" = true ]] && return

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
#   Command arguments.
######################################################################
unittest_main() {
  unittest_setup
  unittest_parse "$@"
  if [[ "$_unittest_flag_help" = true ]]; then
    unittest_help
    return 0
  elif [[ "$_unittest_flag_list" = true ]]; then
    _unittest_collect_testcases
    unittest_list_tests
    return 0
  fi
  unittest_decide_testcases
  unittest_run_testcases
  unittest_print_summary
}
