# Recurrence Olympiad Solver

A Wolfram Mathematica app for olympiad-style recurrence relations such as:

```wl
a[n] == 2 a[n - 1] + 5
a[0] == 3
```

For this example the app finds:

```wl
a[n] == -5 + 8 2^n
```

## Run the App

Open Mathematica and evaluate:

```wl
Get["C:\\Users\\Artensar\\Desktop\\Codex Projects\\Project 1\\RecurrenceOlympiadSolver\\RecurrenceOlympiadSolverApp.wl"]
```

The app opens in a new Mathematica document.

## What It Does

- Parses a recurrence and one or more initial conditions.
- Uses `RSolveValue` to find a closed form.
- Generates a term table for a selected range of `n`.
- Generates terms by forward iteration for supported nonlinear first-order recurrences even when no closed form exists.
- Plots numeric terms.
- Reverse-engineers numeric sequences from terms using finite differences, linear recurrence detection, and `FindSequenceFunction`.
- Solves modular questions for first-order affine integer recurrences:
  - value of `a[N] mod m`
  - last digit, using modulus `10`
  - divisibility, using target remainder `0`
  - target remainder checks
  - eventual period modulo `m`
- Detects first-order affine recurrences of the form:

```wl
a[n] == r a[n - 1] + b
```

or:

```wl
a[n + 1] == r a[n] + b
```

When that form is detected, the app shows the olympiad fixed-point trick:

```wl
c == r c + b
```

Then the shifted sequence becomes geometric.

## Use the Solver Programmatically

```wl
Get["C:\\Users\\Artensar\\Desktop\\Codex Projects\\Project 1\\RecurrenceOlympiadSolver\\Kernel\\RecurrenceOlympiadSolver.wl"];

result = RecurrenceOlympiadSolver`SolveRecurrenceProblem[
  "a[n] == 2 a[n - 1] + 5",
  "a[0] == 3",
  "a",
  "n",
  "TermRange" -> {0, 10}
];

result["ClosedForm"]
result["Terms"]
```

Modular question example:

```wl
modular = RecurrenceOlympiadSolver`AnalyzeModularRecurrence[
  result["Recurrence"],
  result["InitialConditions"],
  result["Sequence"],
  result["Index"],
  10,
  100,
  3
];

modular["ValueMod"]
modular["MatchesTargetResidueQ"]
modular["Period"]
```

For the photo example, this finds:

```wl
a[100] mod 10 == 3
```

## Built-in Modular Examples

The app includes five buttons under `Modular example tests`.
Each button loads the recurrence, solves it, fills the modular fields, and runs the modular solver.

| Button | Question | Expected result |
| --- | --- | --- |
| Last digit | `a[n] == 2 a[n - 1] + 5`, `a[0] == 3`; find the last digit of `a[100]`. | `a[100] mod 10 == 3`; period length `4`. |
| Divisible by 7 | `b[n] == 2 b[n - 1] + 1`, `b[0] == 0`; decide whether `b[12]` is divisible by `7`. | `b[12] mod 7 == 0`; period length `3`. |
| Invariant remainder | `c[n] == 5 c[n - 1] + 2`, `c[0] == 4`; find `c[25] mod 9`. | `c[25] mod 9 == 4`; period length `1`. |
| Period modulo 11 | `p[n] == 3 p[n - 1] + 4`, `p[0] == 2`; find `p[50] mod 11`. | `p[50] mod 11 == 2`; period length `5`. |
| Last two digits | `s[n] == 10 s[n - 1] + 7`, `s[0] == 3`; find the last two digits of `s[2026]`. | `s[2026] mod 100 == 77`; eventual period length `1`. |

## Number Sequence Classifier

The app has a separate `Number sequence classifier` section for reverse-engineering a sequence from given terms.
It accepts either Wolfram lists or comma-separated numbers:

```wl
{1, 1, 2, 3, 5, 8}
```

or:

```text
1, 1, 2, 3, 5, 8
```

It computes:

- finite difference rows
- the first constant-difference level, when one exists
- linear recurrence coefficients from `FindLinearRecurrence`
- a candidate formula from `FindSequenceFunction`
- next predicted terms

Built-in examples:

| Button | Input | Detected result |
| --- | --- | --- |
| Fibonacci | `{1, 1, 2, 3, 5, 8}` | `a[n] == a[n - 1] + a[n - 2]`; next term `13`. |
| Lucas | `{1, 3, 4, 7, 11}` | `a[n] == a[n - 1] + a[n - 2]`; next term `18`. |
| Linear predictor | `{2, 5, 13, 35, 97}` | `a[n] == 5 a[n - 1] - 6 a[n - 2]`; next term `275`. |
| Squares | `{1, 4, 9, 16, 25, 36}` | constant second differences; next term `49`. |
| Cubes + 1 | `{2, 9, 28, 65, 126}` | constant third differences; next term `217`. |
| Alt rational | `{0, 3/2, -2/3, 5/4, -4/5}` | `a[n] == (-1)^n + 1/n`; next term `7/6`. |

## Run the Smoke Test

From PowerShell:

```powershell
& "C:\Program Files\Wolfram Research\Wolfram\14.3\WolframKernel.exe" -script "C:\Users\Artensar\Desktop\Codex Projects\Project 1\RecurrenceOlympiadSolver\Tests\SmokeTest.wls"
```

The script writes `Tests\SmokeTest.out` and exits with a nonzero status if the photo example fails.

## Input Format

Use Wolfram Language syntax:

- Use `==` for equations.
- Use square brackets for sequences: `a[n]`, not `a_n`.
- Write multiplication explicitly or with a space: `2 a[n - 1]`.
- Separate multiple initial conditions with new lines or semicolons.

Examples:

```wl
u[n + 1] == 3 u[n] - 4
u[0] == 2
```

```wl
x[n] == x[n - 1] + 7
x[0] == 5
```

Nonlinear first-order example:

```wl
a[n + 1] == a[n] + a[n]^2
a[1] == 3
```

This recurrence does not usually have a simple `RSolve` closed form, but the app now computes the term table forward from `a[1]`.
If the selected range starts before the initial index, such as `0 to 10`, the table starts at the first known computable index.
