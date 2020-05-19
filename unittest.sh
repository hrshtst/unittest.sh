#!/usr/bin/env bash

# unittest.sh
#
# This script provides a micro unit testing framework for bash shell
# scripts. Each test case consists of a short description and shell
# commands to be tested. Note that this framework does not provide any
# assertion command like `assertEqual`. Instead, it harnesses a trap
# on `ERR` signal, which enabled with the `errtrace` option by the
# `set` built-in command. If every command in a test case exits with
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
#   describe "adding numbers using bc"
#   result="$(echo 2+2 | bc)"
#   [ "$result" -eq 4 ]
# }
#
# testcase_run() {
#   describe "getting the word 'bar' with cut command"
#   run echo 'foo bar baz' | cut -d' ' -f2
#   [ "$status" -eq 0 ]
#   [ "$output" = "bar" ]
# }
#
# testcase_skip() {
#   describe "skip test"
#   skip "foo command returns 0 but not now"
#   run foo
#   [ "$status" -eq 0 ]
# }
#
# testcase_fail() {
#   describe "this always fails"
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
# in the first line with the `describe` helper command. Afterwards,
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
# Finally, a `unittest_main` command should be put with command line
# arguments to run all test cases and show results.
#
# Output format of the results, ideas of `run` and `skip` commands and
# `$status` and `$output` variables, etc. are adopted from the Bash
# Automated Testing System (a.k.a BATS), which is hosted on
# [https://github.com/sstephenson/bats] by Sam Stephenson and
# currently-maintained version on
# [https://github.com/bats-core/bats-core] by bats-core contributors.
# I reimplemented almost the same functionality, but do not express
# their copyrights explicitly. I would like to thank them here.


### Setting shell options.

# Treat unset variables and parameters as an error.
set -u

# Set an option so that any trap on ERR signal is caught to turn
# `unittest_failed` flag on. This is the same as `set -E`. Note that
# `set -o errexit` or `set -e` can not be used here since that option
# exits immediately when ERR is sent.
set -o errtrace
trap unittest_errtrap ERR


### Global variables used throughout running the test script.

# Contains a filename of the test script.
unittest_script_filename="${BASH_SOURCE[1]}"

# Contains the working directory to run the script. Its default value
# is the current working directory.
unittest_working_directory="$(pwd)"


### Flags to control behavior based on the command line arguments.

# Flag to show help message and exit.
unittest_flag_help=false

# Flag to show the list available tests and exit.
unittest_flag_list=false

# Flag to force to run tests specified as skipped.
unittest_flag_force=false


### Global variables which store test case names and manage their
### results.

# An array which contains all the function names defined in the test
# script. It is built by the `unittest_collect_testcases` function.
unittest_all_tests=()

# An array which contains all the descriptions provided by the user
# with the `describe` command.
unittest_all_descriptions=()

# An array which contains specified test cases to be run. Unlike
# `unittest_tests_to_run`, this array is allowed to store test
# function names, test descriptions or test indices.
unittest_specified_tests=()

# An array which contains function names to be run. Unlike
# `unittest_specified_tests`, this array only stores test function
# names.
unittest_tests_to_run=()

# An array which contains function names actually executed.
unittest_executed_tests=()

# An array which contains function names of passed test cases.
unittest_passed_tests=()

# An array which contains function names of failed test cases.
unittest_failed_tests=()

# An array which contains function names of skipped test cases.
unittest_skipped_tests=()


### Global variables cleared or initialized prior to running each test
### case.

# Contains a function which is about to run (or currently running) as
# a test case. Its value should start with 'testcase_' so as to be
# collected automatically by `unittest_collect_testcases`.
unittest_testcase=

# Contains a string which describes the current test case. It is given
# by the `describe` command.
unittest_description=

# Contains notes why a test case is skipped. It is given as an
# optional argument of the `skip` command.
unittest_skip_note=

# Keeps the state whether a test case is failed or not. When it is set
# to `true`, it means the most recent test case failed.
unittest_failed=false

# When a test case is skipped, this flag is set to `true`.
unittest_skipped=false

# An array which contains source filenames corresponding to functions
# being executed when ERR signal is trapped.
unittest_err_source=()

# An array which contains line numbers in source files corresponding
# to functions being executed when ERR signal is trapped.
unittest_err_lineno=()

# An array which contains statuses returned from functions when ERR
# signal is trapped.
unittest_err_status=()


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


### Utility functions

######################################################################
# Output an error message to the standard error.
# Globals:
#   None
# Arguments:
#   An error message, a string.
#   A flag to show an additional info, a boolean (optional)
# Outputs:
#   Error message to the standard error.
######################################################################
error() {
  local lineno
  local funcname
  local source
  local show_info="${2:-true}"
  local msg="${1}"

  if [[ $show_info = true ]]; then
    read -r lineno funcname source <<< "$(caller 0)"
    msg="$source:$lineno [in $funcname()] $msg"
  fi
  echo "$msg" >&2
}

### Helper functions

# NOTE:
#   Functions whose name starts with `unittest_` are core helper
#   functions which construct a logical structure of the
#   `unittest_main` function and basically their functionalities are
#   testsd in `test_unittest.sh`. Meanwhile, functions whose name
#   starts with `_unittest_` are internal helper functions, so they
#   are not tested in the script.

######################################################################
# Initialize global variables listed below which are used throughout
# running all tests.
# Globals:
#   unittest_all_tests
#   unittest_all_descriptions
#   unittest_specified_tests
#   unittest_tests_to_run
#   unittest_executed_tests
#   unittest_passed_tests
#   unittest_failed_tests
#   unittest_skipped_tests
#   unittest_flag_help
#   unittest_flag_list
#   unittest_flag_force
# Arguments:
#   None
######################################################################
unittest_initialize() {
  unittest_all_tests=()
  unittest_all_descriptions=()
  unittest_specified_tests=()
  unittest_tests_to_run=()
  unittest_executed_tests=()
  unittest_passed_tests=()
  unittest_failed_tests=()
  unittest_skipped_tests=()
  unittest_flag_help=false
  unittest_flag_list=false
  unittest_flag_force=false
}

######################################################################
# Executed when ERR signal is caught. Turn the failed flag on and
# store the source file, the location and the status code where the
# ERR signal has been sent.
# Globals:
#   unittest_failed
#   unittest_err_source
#   unittest_err_lineno
#   unittest_err_status
# Arguments:
#   None
######################################################################
unittest_errtrap() {
  # Keep the exit status returned by the last function or command.
  local _status="$?"

  # Check if ERR signal is sent from the test script.
  if [[ "${BASH_SOURCE[1]}" = "$unittest_script_filename" ]]; then
    unittest_failed=true
    unittest_err_source+=("${BASH_SOURCE[1]}")
    unittest_err_lineno+=("${BASH_LINENO[0]}")
    unittest_err_status+=("$_status")
  fi
}

######################################################################
# Reset variables which store the result and attributes of each test
# to their default values. This function should be executed prior to
# running each test.
# Globals:
#   unittest_description
#   unittest_skip_note
#   unittest_failed
#   unittest_skipped
#   unittest_err_source
#   unittest_err_lineno
#   unittest_err_status
# Arguments:
#   None
######################################################################
unittest_reset_vars() {
  unittest_description=
  unittest_skip_note=
  unittest_failed=false
  unittest_skipped=false
  unittest_err_source=()
  unittest_err_lineno=()
  unittest_err_status=()
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
  local regex_find_desc="^[[:space:]]\+describe.*"
  local sed_remove_quote="s/[\"';]//g"
  local sed_find_desc="s/^[[:space:]]\+describe \(.*\)/\1/p"
  local _line=
  local _desc=

  # Find lines which contains `describe` at the beginning.
  _line="$(declare -f "$_func" | grep -e "$regex_find_desc")"
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
# Return the index of the array `unittest_all_descriptions` whose
# value is the supplied description.
# Globals:
#   unittest_all_descriptions
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
  for index in "${!unittest_all_descriptions[@]}"; do
    if [[ "$desc" == "${unittest_all_descriptions[$index]}" ]]; then
      found=true
    fi
  done
  [[ "$found" == true  ]] && echo "$index"
}

######################################################################
# Collects functions whose names begin with `testcase_` and their
# descriptions provided by the user. Function names and descriptions
# are stored in global variables `unittest_all_tests` and
# `unittest_all_descriptions`, respectively.
# Globals:
#   unittest_all_tests
#   unittest_all_descriptions
# Arguments:
#   None
######################################################################
unittest_collect_testcases() {
  local regex_find_testcase="^testcase_.*"
  local _func=
  local _desc=

  while IFS= read -r _func; do
    _desc="$(_unittest_extract_description "$_func")"
    unittest_all_tests+=("$_func")
    unittest_all_descriptions+=("$_desc")
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
#   unittest_description
# Arguments:
#   None.
# Outputs:
#   Writes its description to stdout.
######################################################################
_unittest_describe() {
  if [[ -z "$unittest_description" ]]; then
    echo "$unittest_testcase"
  else
    echo "$unittest_description"
  fi
}

######################################################################
# Execute pre-processing stuff before running each test.
# Globals:
#   unittest_testcase
# Arguments:
#   Test case to run, a function name.
######################################################################
_unittest_preprocesses() {
  # set the function name of the current test case
  unittest_testcase="$1"
  # reset variables
  unittest_reset_vars
  if [[ "$unittest_flag_force" = false ]]; then
    # handle a skipped test
    _unittest_handle_skipped_test "$unittest_testcase"
  fi
}

######################################################################
# Categorize an executed test case into one of the groups, passed,
# failed or skipped.
# Gloabls:
#   unittest_failed
#   unittest_skipped
#   unittest_passed_tests
#   unittest_failed_tests
#   unittest_skipped_tests
# Arguments:
#   Test case to run, a function name
######################################################################
_unittest_categorize_by_result() {
  local testcase="$1"

  unittest_executed_tests+=("$testcase")
  if [[ $unittest_skipped = true ]]; then
    unittest_skipped_tests+=("$testcase")
  elif [[ $unittest_failed = true ]]; then
    unittest_failed_tests+=("$testcase")
  else
    unittest_passed_tests+=("$testcase")
  fi
}

######################################################################
# Execute post-processing stuff after running each test.
# Globals:
#   unittest_skipped_tests
#   unittest_failed_tests
#   unittest_passed_tests
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
  for i in "${!unittest_err_status[@]}"; do
    source="${unittest_err_source[$i]}"
    lineno="${unittest_err_lineno[$i]}"
    failure_location="$(printf "test file %s, line %d" "$source" "$lineno")"
    failure_detail="$(sed -e "${lineno}q;d" "$source" | sed -e "s/^[[:space:]]*//")"
    printf "%s   (in %s)\n     \`%s' failed with %d%s\n"\
           "$brightred" "$failure_location" "$failure_detail" \
           "${unittest_err_status[$i]}" "$reset"
  done
}

_unittest_print_result_skip() {
  local skip_note
  skip_note="${unittest_skip_note:+: }${unittest_skip_note}"
  printf " - %s (skipped%s)\n" "$(_unittest_describe)" "$skip_note"
}

_unittest_print_result() {
  if [[ $unittest_skipped = true ]]; then
    _unittest_print_result_skip
  elif [[ $unittest_failed = true ]]; then
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
  unittest_initialize
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
Run unit tests defined in \`${unittest_script_filename#./}' and print
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
  printf "%d tests found\n" "${#unittest_all_tests[@]}"
  for index in "${!unittest_all_tests[@]}"; do
    func="${unittest_all_tests[$index]}"
    desc="${unittest_all_descriptions[$index]}"
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
        unittest_flag_list=true
        shift
        ;;
      -f|--force-run)
        unittest_flag_force=true
        shift
        ;;
      -h|--help)
        unittest_flag_help=true
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
 unittest_specified_tests=("${testspecs[@]}")
}

######################################################################
# Decide which testcases should be run.
# Globals:
#   None
# Arguments:
#   None
######################################################################
unittest_decide_testcases() {
  unittest_collect_testcases
}

unittest_run_testcases() {
  local testcase

  for testcase in "${unittest_all_tests[@]}"; do
    _unittest_preprocesses "$testcase"
    setup
    $unittest_testcase
    teardown
    _unittest_postprocesses "$testcase"
    _unittest_print_result
  done
}

unittest_print_summary() {
  local n_tests n_failed n_skipped
  local summary

  # store numbers of executed tests in variables
  n_tests=${#unittest_all_tests[@]}
  n_failed=${#unittest_failed_tests[@]}
  n_skipped=${#unittest_skipped_tests[@]}

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
# `describe` command allows you to give a short description of each
# test case to the test runner
# Globals:
#   _unjittest_description
# Arguments:
#   Description of test case, string
######################################################################
describe() {
  unittest_description="${*:-$unittest_testcase}"
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
#   unittest_skip_note
#   unittest_skipped
# Arguments:
#   Reason for skipping, string (optional)
######################################################################
skip() {
  [[ "$unittest_flag_force" = true ]] && return

  unittest_skip_note="${1:-}"
  unittest_skipped=true
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
  if [[ "$unittest_flag_help" = true ]]; then
    unittest_help
    return 0
  elif [[ "$unittest_flag_list" = true ]]; then
    unittest_collect_testcases
    unittest_list_tests
    return 0
  fi
  unittest_decide_testcases
  unittest_run_testcases
  unittest_print_summary
}
