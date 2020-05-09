# unittest.sh

A micro unit testing framework for bash scripts.

## Motives

This library provides a unit testing framework with minimum functions
for bash scripts. Most of basic ideas are incorporated from [Bash
Automated Testing System](https://github.com/sstephenson/bats), but
this framework does not require a unique format to write test cases
nor an additional command for running tests. Thus, you can write and
run a test script as like as a bash script.

## Usage

Each test case consists of a short description of it and shell
commands to be tested. Unlike frameworks for other languages, this
framework does not provide any assertion commands. Instead, it
harnesses a trap on `ERR` signal, which enabled with the `errtrace`
option by the `set` command provided by bash shell. If every command
in a test case exits with the `0` status code, it means that the test
passes.

### Installation

A test script can be written as a standard bash script, so you should
put a shebang to the head of a script like:

``` shell
#!/usr/bin/env bash
```

In order to use this framework, sourcing the `unittsst.sh` is needed.

``` shell
source unittest.sh
```

### Definition of a test case

Each test case is defined as a function whose name starts with
`testcase_`. Inside a test case a short description of the test should
be put in the first line with the `it` helper command. Afterwards,
standard shell commands can be written. If every command exits with
the `0` status, the test passes.

``` shell
testcase_add() {
    it "adds numbers unsing bc"
    result="$(echo 2+2 | bc)"
    [ "$result" -eq 4 ]
}
```

### Helper commands

#### run command
The helper command `run` invokes arguments as a bash command, then
stores its exit status in a variable `$status`. The `run` command
itself exits with `0` status code so that you can continue following
assertions. Also, the `$output` variable contains the contents of the
standard output and the standard errors. An example to use the `run`
command is show below:

``` shell
testcase_run() {
    it "gets the word 'bar' with cut command"
    run echo 'foo bar baz' | cut -d' ' -f2
    [ "$status" -eq 0 ]
    [ "$output" = "bar" ]
}
```

#### skip command

To skip some test temporarily, you can use the `skip` command. The
`skip` command accepts the reason for skipping as an additional
argument. Tha usage is shown in the code below:

``` shell
testcase_skip() {
    it "is skipped"
    skip "foo command return 0 but not now"
    run foo
    [ "$status" -eq 0 ]
}
```

#### setup and teardown

Additionally, `setup` and `teardown` functions can be defined, which
are executed before and after each test case, respectively.

### Running tests

To run the tests and show the results on the console, it is needed to
put `unittest_main` command at the end of the script. The order to
execute tests is sorted alphabetically.

``` shell
unittest_main "$@"
```

The test script can be executed like as a bash script. The results are
shown on the console like as follows:

```
$ ./test_example.sh
 ✓ adds numbers using bc
 ✗ always fails
   (in test file ./test_example.sh, line 27)
     `false' failed with 1
 ✓ gets the word 'bar' with cut command
 - is skipped (skipped: foo command return 0 but not now)

4 tests, 1 failure, 1 skipped
```

## License

[MIT](https://choosealicense.com/licenses/mit/)
