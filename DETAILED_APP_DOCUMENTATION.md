# Recurrence Olympiad Solver - Detailed App Documentation

## Overview

Recurrence Olympiad Solver is a Wolfram Mathematica / Wolfram Language app for solving and exploring olympiad-style recurrence and sequence problems.

The app has three main goals:

1. Solve recurrence relations given in Wolfram Language syntax.
2. Answer modular arithmetic questions about recurrence sequences.
3. Reverse-engineer number sequences from their first terms.

The project is designed for students who practice math olympiad, contest math, and discrete mathematics problems involving sequences, recurrences, modular periods, divisibility, and pattern recognition.

## Main Files

The project folder is:

```text
RecurrenceOlympiadSolver/
```

Important files:

```text
RecurrenceOlympiadSolverApp.wl
```

Launcher file. This is the file users run in Mathematica to open the app.

```text
Kernel/RecurrenceOlympiadSolver.wl
```

Main Wolfram Language package. It contains the app UI and all math logic.

```text
Tests/SmokeTest.wls
```

Automated test script for WolframKernel. It checks the main recurrence solver, modular examples, nonlinear iteration, and number sequence classifier.

```text
README.md
```

Short GitHub landing documentation.

```text
DETAILED_APP_DOCUMENTATION.md
```

This detailed documentation file.

```text
.gitignore
```

Ignores generated test output files such as `Tests/*.out`.

## Requirements

The app requires Wolfram Mathematica or Wolfram Engine.

Tested with:

```text
Wolfram 14.3
```

The smoke test uses:

```text
WolframKernel.exe
```

On Windows, the default tested path was:

```text
C:\Program Files\Wolfram Research\Wolfram\14.3\WolframKernel.exe
```

If your Wolfram version is installed somewhere else, adjust the path in the test command.

## How to Run the App

Open Mathematica, create a new notebook, and evaluate:

```wl
Get["C:\\Users\\Artensar\\Desktop\\Codex Projects\\Project 1\\RecurrenceOlympiadSolver\\RecurrenceOlympiadSolverApp.wl"]
```

If the project is downloaded from GitHub, change the path to wherever the project folder is located.

For example:

```wl
Get["C:\\Path\\To\\RecurrenceOlympiadSolver\\RecurrenceOlympiadSolverApp.wl"]
```

The app opens a new Mathematica document with a tabbed interface.

## User Interface Structure

The app has three tabs:

1. Recurrence Solver
2. Number Sequence
3. Modular Questions

Each tab is focused on a different type of olympiad-style sequence problem.

## Tab 1: Recurrence Solver

The Recurrence Solver tab is for problems where the recurrence relation is already given.

Example input:

```wl
a[n] == 2 a[n - 1] + 5
```

Initial condition:

```wl
a[0] == 3
```

The app finds:

```wl
a[n] == -5 + 8 2^n
```

It also generates a table of terms:

```text
n   a[n]
0   3
1   11
2   27
3   59
4   123
```

### Supported Recurrence Inputs

Use Wolfram Language syntax:

```wl
a[n] == 2 a[n - 1] + 5
```

Do not use handwritten subscript notation like:

```text
a_n = 2a_{n-1} + 5
```

Use square brackets:

```wl
a[n]
```

Use `==` for equations:

```wl
a[0] == 3
```

Use explicit multiplication or a space:

```wl
2 a[n - 1]
```

### Closed-Form Solving

The app uses:

```wl
RSolveValue
```

to find closed forms when possible.

Examples it can solve:

```wl
a[n] == 2 a[n - 1] + 5
a[0] == 3
```

```wl
u[n + 1] == 3 u[n] - 4
u[0] == 2
```

### First-Order Affine Recurrences

The app detects recurrences of the form:

```wl
a[n] == r a[n - 1] + b
```

or:

```wl
a[n + 1] == r a[n] + b
```

For this type it computes:

- ratio `r`
- constant `b`
- fixed point
- closed form
- term table
- plot

Example:

```wl
a[n] == 2 a[n - 1] + 5
a[0] == 3
```

The fixed point is:

```wl
c == 2 c + 5
c == -5
```

The closed form is:

```wl
a[n] == -5 + 8 2^n
```

### Nonlinear First-Order Iteration

Some nonlinear recurrences do not have a simple closed form, but terms can still be generated.

Example:

```wl
a[n + 1] == a[n] + a[n]^2
a[1] == 3
```

The app computes forward:

```wl
a[1] = 3
a[2] = 12
a[3] = 156
a[4] = 24492
a[5] = 599882556
```

If the selected term range starts before the initial index, the table starts from the first known computable term.

For example, if the range is:

```text
0 to 10
```

but the initial condition is:

```wl
a[1] == 3
```

then the table starts from:

```wl
a[1]
```

because `a[0]` is not defined by the input.

## Tab 2: Number Sequence Classifier

The Number Sequence tab is for problems where only the first terms are given.

Example:

```text
1, 1, 2, 3, 5, 8
```

The app tries to reverse-engineer a rule.

It accepts both:

```wl
{1, 1, 2, 3, 5, 8}
```

and:

```text
1, 1, 2, 3, 5, 8
```

### What the Classifier Computes

The classifier computes:

- input length
- start index
- finite difference table
- constant-difference level
- linear recurrence coefficients
- candidate sequence function
- detected model, when available
- next predicted terms

### Fibonacci Example

Input:

```text
1, 1, 2, 3, 5, 8
```

Detected recurrence:

```wl
a[n] == a[n - 1] + a[n - 2]
```

Next terms:

```text
13, 21, 34, 55, 89
```

### Lucas Example

Input:

```text
1, 3, 4, 7, 11
```

Detected recurrence:

```wl
a[n] == a[n - 1] + a[n - 2]
```

Next terms:

```text
18, 29, 47, 76, 123
```

### Linear Predictor Example

Input:

```text
2, 5, 13, 35, 97
```

Detected recurrence:

```wl
a[n] == 5 a[n - 1] - 6 a[n - 2]
```

Next term:

```text
275
```

### Polynomial Difference Examples

Input:

```text
1, 4, 9, 16, 25, 36
```

This has constant second differences and behaves like:

```wl
a[n] == n^2
```

Input:

```text
2, 9, 28, 65, 126
```

This has constant third differences and behaves like:

```wl
a[n] == n^3 + 1
```

### Alternating Rational Example

Input:

```text
0, 3/2, -2/3, 5/4, -4/5
```

Detected model:

```wl
a[n] == (-1)^n + 1/n
```

Next terms:

```text
7/6, -6/7, 9/8, -8/9, 11/10
```

### Prime and Factorial Examples

The app can recognize many expressions through `FindSequenceFunction`.

Prime example:

```text
2, 3, 5, 7, 11, 13
```

Expected:

```wl
a[n] == Prime[n]
```

Factorial example:

```text
1, 2, 6, 24, 120, 720
```

Expected:

```wl
a[n] == n!
```

Shifted factorial example:

```text
2, 6, 24, 120, 720
```

Mathematica may display this as:

```wl
Gamma[n + 2]
```

which is equivalent to:

```wl
(n + 1)!
```

### Current Classifier Limitations

The classifier can find many valid formulas, but a short sequence can have many possible rules.

Sometimes Mathematica returns a formula that is correct but not the most human-friendly olympiad-style answer.

Examples:

For:

```text
1, 1, 2, 2, 3, 3
```

the natural formula is:

```wl
Ceiling[n/2]
```

but Mathematica may produce a stranger valid expression.

For:

```text
2, 5, 7, 2, 5, 7
```

the natural rule is:

```text
period 3, repeating {2, 5, 7}
```

but Mathematica may produce a long trigonometric formula.

Future improvements should rank human-simple patterns above complicated formulas.

## Tab 3: Modular Questions

The Modular Questions tab is for recurrence questions involving remainders.

It can answer:

- `a[N] mod m`
- last digit questions
- last two digit questions
- divisibility checks
- target remainder checks
- modular period detection

### Last Digit Example

Recurrence:

```wl
a[n] == 2 a[n - 1] + 5
a[0] == 3
```

Question:

```text
Find the last digit of a[100].
```

Use:

```text
modulus = 10
target index = 100
test remainder = 3
```

The app finds:

```wl
a[100] mod 10 == 3
```

### Divisibility Example

Recurrence:

```wl
b[n] == 2 b[n - 1] + 1
b[0] == 0
```

Question:

```text
Is b[12] divisible by 7?
```

Use:

```text
modulus = 7
target index = 12
test remainder = 0
```

The app finds:

```wl
b[12] mod 7 == 0
```

So the answer is yes.

### Last Two Digits Example

Recurrence:

```wl
s[n] == 10 s[n - 1] + 7
s[0] == 3
```

Question:

```text
Find the last two digits of s[2026].
```

Use:

```text
modulus = 100
target index = 2026
```

The app finds:

```wl
s[2026] mod 100 == 77
```

### Modular Periods

For supported integer first-order recurrences, the app searches for repeating residues modulo `m`.

Example:

```wl
p[n] == 3 p[n - 1] + 4
p[0] == 2
```

Modulo:

```text
11
```

The app detects a period length of:

```text
5
```

## Internal Math Functions

The package exposes several useful functions.

### SolveRecurrenceProblem

```wl
SolveRecurrenceProblem[
  recurrenceText,
  initialText,
  sequenceName,
  indexName,
  "TermRange" -> {0, 10}
]
```

Parses the recurrence and initial conditions, then returns an association containing:

- success status
- parsed recurrence
- initial conditions
- closed form
- generated terms
- olympiad affine analysis

### AnalyzeModularRecurrence

```wl
AnalyzeModularRecurrence[
  recurrence,
  initials,
  seq,
  n,
  modulus,
  targetIndex,
  targetResidue
]
```

Solves modular questions for supported integer recurrences.

### AnalyzeNumberSequence

```wl
AnalyzeNumberSequence[
  "1, 1, 2, 3, 5, 8",
  1
]
```

Reverse-engineers a number sequence from terms.

Returns an association containing:

- parsed values
- difference rows
- detected recurrence
- candidate formula
- predicted next terms

## Testing

Run the smoke test from PowerShell:

```powershell
& "C:\Program Files\Wolfram Research\Wolfram\14.3\WolframKernel.exe" -script "C:\Users\Artensar\Desktop\Codex Projects\Project 1\RecurrenceOlympiadSolver\Tests\SmokeTest.wls"
```

The smoke test writes:

```text
Tests/SmokeTest.out
```

This file is generated and should not be committed.

The test checks:

- first-order affine recurrence solving
- closed form for the photo example
- modular arithmetic examples
- nonlinear recurrence forward iteration
- number sequence classifier examples
- alternating rational sequence detection
- app construction

Expected output:

```text
PASS: photo recurrence gives -5 + 2^(3 + n), all modular examples passed, nonlinear iteration works, and sequence classifier works
```

## Recommended GitHub Repository Structure

Upload the project folder with this structure:

```text
RecurrenceOlympiadSolver/
  .gitignore
  README.md
  DETAILED_APP_DOCUMENTATION.md
  RecurrenceOlympiadSolverApp.wl
  Kernel/
    RecurrenceOlympiadSolver.wl
  Tests/
    SmokeTest.wls
```

Do not upload generated files:

```text
Tests/*.out
```

## Suggested GitHub Description

Short description:

```text
A Wolfram Mathematica app for olympiad-style recurrence solving, modular sequence questions, and number sequence classification.
```

Longer description:

```text
Recurrence Olympiad Solver is a Wolfram Language app for solving recurrence relations, generating terms, answering modular questions, detecting periods, and reverse-engineering number sequences from initial terms. It supports closed-form solving with RSolveValue, nonlinear forward iteration, modular arithmetic analysis, finite differences, linear recurrence detection, and sequence formula guessing.
```

## Suggested GitHub Topics

```text
wolfram-language
mathematica
recurrence-relations
number-theory
math-olympiad
sequence-classifier
modular-arithmetic
discrete-math
```

## Known Limitations

The app is useful, but it is not a complete sequence intelligence system.

Known limitations:

- It may produce a mathematically valid but non-human-friendly formula.
- It does not yet rank multiple candidate rules by simplicity.
- It does not yet always simplify `Gamma[n + 2]` into `(n + 1)!`.
- It does not yet have a dedicated prime-power detector such as `Prime[n]^2`.
- It does not yet have a dedicated floor/ceiling detector.
- It does not yet have a clean periodic-pattern display.
- It does not yet fully classify odd/even piecewise sequences in a readable way.
- It does not yet solve every nonlinear recurrence from terms alone.

## Future Improvements

Good future math upgrades:

1. Candidate ranking system.
2. Human-friendly formula simplifier.
3. Prime-power detector.
4. Floor and ceiling sequence detector.
5. Periodic pattern detector.
6. Alternating polynomial detector.
7. Odd/even subsequence classifier.
8. Direct question mode for `a[N]`, `a[N] mod m`, and first `n` satisfying a condition.
9. Better display for factorials, binomial coefficients, triangular numbers, and periodic patterns.
10. Candidate list with confidence levels.

## License Recommendation

If you plan to make the project open source, add a license file.

A common permissive choice is:

```text
MIT License
```

For GitHub, create a file named:

```text
LICENSE
```

and choose MIT, Apache-2.0, or another license depending on how you want others to use the code.
