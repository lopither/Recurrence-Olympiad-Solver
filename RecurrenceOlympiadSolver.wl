BeginPackage["RecurrenceOlympiadSolver`"];

RecurrenceOlympiadSolverApp::usage =
  "RecurrenceOlympiadSolverApp[] opens an interactive Wolfram Language app for solving olympiad-style recurrence relations.";

SolveRecurrenceProblem::usage =
  "SolveRecurrenceProblem[recurrenceText, initialText, sequenceName, indexName] parses and solves a recurrence with initial conditions.";

OlympiadLinearRecurrenceAnalysis::usage =
  "OlympiadLinearRecurrenceAnalysis[recurrence, initials, seq, n] detects and explains first-order affine recurrences.";

GenerateRecurrenceTerms::usage =
  "GenerateRecurrenceTerms[equations, seq, n, {nmin, nmax}, closedForm] generates a table of recurrence terms.";

AnalyzeModularRecurrence::usage =
  "AnalyzeModularRecurrence[recurrence, initials, seq, n, modulus, targetIndex, targetResidue] solves modular questions for supported recurrences.";

SampleRecurrenceProblem::usage =
  "SampleRecurrenceProblem[name] returns a preset recurrence problem for the app.";

SampleModularQuestion::usage =
  "SampleModularQuestion[name] returns a preset modular recurrence question for the app.";

AnalyzeNumberSequence::usage =
  "AnalyzeNumberSequence[text, startIndex] reverse-engineers a numeric sequence using differences, linear recurrence detection, and FindSequenceFunction.";

SampleNumberSequence::usage =
  "SampleNumberSequence[name] returns a preset numeric sequence classifier example for the app.";

Begin["`Private`"];

ClearAll[
  validSymbolNameQ,
  makeGlobalSymbol,
  parseHeldExpression,
  parseOneEquation,
  parseEquationList,
  closedFormUsableQ,
  analyzeAffineRightHandSide,
  detectFirstOrderAffine,
  detectFirstOrderIterator,
  firstOrderStepValue,
  generateFirstOrderIteratorTerms,
  firstInitialValue,
  integerValue,
  matrixPowerMod,
  affineValueMod,
  findAffinePeriod,
  analyzeIteratorModularRecurrence,
  AnalyzeModularRecurrence,
  SampleModularQuestion,
  parseNumberSequence,
  differenceRows,
  constantDifferenceLevel,
  sequenceFunctionUsableQ,
  fitLinearBasisSequence,
  detectSpecialSequenceFunction,
  linearRecurrenceEquation,
  predictFromLinearRecurrence,
  AnalyzeNumberSequence,
  SampleNumberSequence,
  appColors,
  appShell,
  appCard,
  appTitle,
  appSubtitle,
  appSectionTitle,
  appMuted,
  appError,
  appLabel,
  appButton,
  appInput,
  appTable,
  numberSequenceResultPanel,
  resultView,
  closedFormPanel,
  olympiadPanel,
  termsPanel,
  plotPanel,
  modularResultPanel
];

validSymbolNameQ[name_String] :=
  StringMatchQ[StringTrim[name], RegularExpression["[A-Za-z][A-Za-z0-9$]*"]];

makeGlobalSymbol[name_String] :=
  If[validSymbolNameQ[name],
    ToExpression["Global`" <> StringTrim[name]],
    $Failed
  ];

parseHeldExpression[text_String] := Module[{trimmed = StringTrim[text]},
  If[trimmed === "", Return[Missing["EmptyInput"]]];
  Quiet @ Check[
    Block[{$Context = "Global`", $ContextPath = {"System`", "Global`"}},
      ToExpression[trimmed, StandardForm, HoldComplete]
    ],
    $Failed
  ]
];

parseOneEquation[text_String] := Module[{held = parseHeldExpression[text]},
  Which[
    held === $Failed, $Failed,
    MissingQ[held], held,
    MatchQ[held, HoldComplete[_Equal]], ReleaseHold[held],
    True, $Failed
  ]
];

parseEquationList[text_String] := Module[{parts, parsed},
  parts = DeleteCases[
    StringTrim /@ StringSplit[text, {"\r\n", "\n", ";"}],
    ""
  ];
  If[parts === {}, Return[{}]];
  parsed = parseOneEquation /@ parts;
  If[MemberQ[parsed, $Failed] || AnyTrue[parsed, ! MatchQ[#, _Equal] &],
    $Failed,
    parsed
  ]
];

closedFormUsableQ[expr_] :=
  expr =!= $Failed &&
    ! MissingQ[expr] &&
    FreeQ[HoldComplete[expr], _RSolve | _RSolveValue | _RecurrenceTable];

Options[SolveRecurrenceProblem] = {"TermRange" -> {0, 12}};

SolveRecurrenceProblem[
  recurrenceText_String,
  initialText_String,
  sequenceName_String : "a",
  indexName_String : "n",
  OptionsPattern[]
] := Module[
  {
    seq, idx, recurrence, initials, equations, closedForm, terms,
    analysis, termRange
  },
  seq = makeGlobalSymbol[sequenceName];
  idx = makeGlobalSymbol[indexName];
  termRange = OptionValue["TermRange"];

  If[seq === $Failed || idx === $Failed,
    Return @ <|
      "Success" -> False,
      "Message" -> "Use valid Wolfram symbol names, such as a and n."
    |>
  ];

  recurrence = parseOneEquation[recurrenceText];
  If[recurrence === $Failed || ! MatchQ[recurrence, _Equal],
    Return @ <|
      "Success" -> False,
      "Message" -> "The recurrence must be a Wolfram equation, for example a[n] == 2 a[n - 1] + 5."
    |>
  ];

  initials = parseEquationList[initialText];
  If[initials === $Failed || initials === {},
    Return @ <|
      "Success" -> False,
      "Message" -> "Enter at least one initial condition, for example a[0] == 3."
    |>
  ];

  equations = Join[{recurrence}, initials];
  closedForm = Quiet @ Check[
    FullSimplify @ RSolveValue[equations, seq[idx], idx],
    $Failed
  ];

  If[! closedFormUsableQ[closedForm],
    closedForm = Missing["NoClosedForm"]
  ];

  terms = GenerateRecurrenceTerms[equations, seq, idx, termRange, closedForm];
  analysis = OlympiadLinearRecurrenceAnalysis[recurrence, initials, seq, idx];

  <|
    "Success" -> True,
    "Sequence" -> seq,
    "Index" -> idx,
    "Recurrence" -> recurrence,
    "InitialConditions" -> initials,
    "Equations" -> equations,
    "ClosedForm" -> closedForm,
    "Terms" -> terms,
    "OlympiadAnalysis" -> analysis
  |>
];

GenerateRecurrenceTerms[
  equations_List,
  seq_Symbol,
  idx_Symbol,
  range : {_, _},
  closedForm_ : Automatic
] := Module[{nmin, nmax, values, iteratorTerms},
  {nmin, nmax} = Round /@ range;
  If[! IntegerQ[nmin] || ! IntegerQ[nmax] || nmin > nmax,
    Return[{}]
  ];

  If[closedForm =!= Automatic && closedFormUsableQ[closedForm],
    Return @ Table[
      {k, Quiet @ Check[FullSimplify[closedForm /. idx -> k], Missing["NotAvailable"]]},
      {k, nmin, nmax}
    ]
  ];

  values = Quiet @ Check[
    RecurrenceTable[equations, seq[idx], {idx, nmin, nmax}],
    $Failed
  ];

  If[ListQ[values],
    MapIndexed[{nmin + First[#2] - 1, #1} &, values],
    iteratorTerms = generateFirstOrderIteratorTerms[equations, seq, idx, {nmin, nmax}];
    If[ListQ[iteratorTerms], iteratorTerms, {}]
  ]
];

analyzeAffineRightHandSide[rhs_, previous_, seq_Symbol, idx_Symbol] :=
  Module[{ratio, constant},
    ratio = Quiet @ Check[FullSimplify @ Coefficient[rhs, previous], $Failed];
    If[ratio === $Failed, Return[Missing["BadCoefficient"]]];

    constant = Quiet @ Check[FullSimplify[rhs - ratio previous], $Failed];
    If[
      constant === $Failed ||
        ! FreeQ[ratio, seq[_]] ||
        ! FreeQ[constant, seq[_]] ||
        ! FreeQ[ratio, idx] ||
        ! FreeQ[constant, idx],
      Return[Missing["NotConstantAffine"]]
    ];

    <|"Ratio" -> ratio, "Constant" -> constant|>
  ];

detectFirstOrderAffine[lhs_, rhs_, seq_Symbol, idx_Symbol] :=
  Module[{data},
    If[TrueQ[Simplify[lhs == seq[idx]]],
      data = analyzeAffineRightHandSide[rhs, seq[idx - 1], seq, idx];
      If[AssociationQ[data],
        Return @ Join[
          <|"Current" -> seq[idx], "Previous" -> seq[idx - 1], "Shift" -> 0|>,
          data
        ]
      ]
    ];

    If[TrueQ[Simplify[lhs == seq[idx + 1]]],
      data = analyzeAffineRightHandSide[rhs, seq[idx], seq, idx];
      If[AssociationQ[data],
        Return @ Join[
          <|"Current" -> seq[idx + 1], "Previous" -> seq[idx], "Shift" -> 1|>,
          data
        ]
      ]
    ];

    Missing["NotFirstOrderAffine"]
  ];

detectFirstOrderIterator[recurrence_Equal, seq_Symbol, idx_Symbol] :=
  Module[{lhs, rhs, previous, test},
    {lhs, rhs} = List @@ recurrence;

    If[TrueQ[Simplify[lhs == seq[idx + 1]]],
      previous = seq[idx];
      test = rhs /. previous -> Unique["term"];
      If[FreeQ[test, seq[_]],
        Return @ <|
          "Kind" -> "NextFromCurrent",
          "Previous" -> previous,
          "RightHandSide" -> rhs
        |>
      ]
    ];

    If[TrueQ[Simplify[lhs == seq[idx]]],
      previous = seq[idx - 1];
      test = rhs /. previous -> Unique["term"];
      If[FreeQ[test, seq[_]],
        Return @ <|
          "Kind" -> "CurrentFromPrevious",
          "Previous" -> previous,
          "RightHandSide" -> rhs
        |>
      ]
    ];

    Missing["NotFirstOrderIterator"]
  ];

firstOrderStepValue[form_Association, value_, currentIndex_Integer, idx_Symbol] :=
  Module[{nextIndex = currentIndex + 1, indexValue},
    indexValue = If[form["Kind"] === "NextFromCurrent", currentIndex, nextIndex];
    Quiet @ Check[
      FullSimplify[
        form["RightHandSide"] /. form["Previous"] -> value /. idx -> indexValue
      ],
      $Failed
    ]
  ];

generateFirstOrderIteratorTerms[
  equations_List,
  seq_Symbol,
  idx_Symbol,
  range : {_, _}
] := Module[
  {
    recurrence, form, initial, initialIndex, value, currentIndex,
    nmin, nmax, startIndex, terms = {}, nextValue
  },
  {nmin, nmax} = Round /@ range;
  recurrence = FirstCase[
    equations,
    eq_Equal /; AssociationQ[detectFirstOrderIterator[eq, seq, idx]] :> eq,
    Missing["NoIterator"]
  ];
  If[MissingQ[recurrence], Return[Missing["NoIterator"]]];

  form = detectFirstOrderIterator[recurrence, seq, idx];
  initial = firstInitialValue[equations, seq];
  If[MissingQ[initial], Return[Missing["NoInitialValue"]]];

  {initialIndex, value} = initial;
  If[nmax < initialIndex, Return[{}]];

  startIndex = Max[nmin, initialIndex];
  currentIndex = initialIndex;

  While[currentIndex < startIndex,
    nextValue = firstOrderStepValue[form, value, currentIndex, idx];
    If[nextValue === $Failed, Return[Missing["IterationFailed"]]];
    value = nextValue;
    currentIndex++;
  ];

  While[currentIndex <= nmax,
    AppendTo[terms, {currentIndex, value}];
    If[currentIndex < nmax,
      nextValue = firstOrderStepValue[form, value, currentIndex, idx];
      If[nextValue === $Failed, Return[Missing["IterationFailed"]]];
      value = nextValue;
    ];
    currentIndex++;
  ];

  terms
];

firstInitialValue[initials_List, seq_Symbol] :=
  FirstCase[
    initials,
    HoldPattern[Equal[seq[k_Integer], value_]] :> {k, value},
    Missing["NoInitialValue"]
  ];

OlympiadLinearRecurrenceAnalysis[
  recurrence_Equal,
  initials_List,
  seq_Symbol,
  idx_Symbol
] := Module[
  {
    lhs, rhs, form, initial, initialIndex, initialValue, ratio, constant,
    fixedPoint, closedForm, shiftedClosedForm
  },
  {lhs, rhs} = List @@ recurrence;
  form = detectFirstOrderAffine[lhs, rhs, seq, idx];
  If[! AssociationQ[form], Return[form]];

  initial = firstInitialValue[initials, seq];
  If[MissingQ[initial], Return[initial]];

  {initialIndex, initialValue} = initial;
  ratio = form["Ratio"];
  constant = form["Constant"];

  If[TrueQ[Simplify[ratio == 1]],
    fixedPoint = Missing["NoFiniteFixedPoint"];
    closedForm = FullSimplify[initialValue + constant (idx - initialIndex)],
    fixedPoint = FullSimplify[constant/(1 - ratio)];
    shiftedClosedForm = FullSimplify[
      fixedPoint + (initialValue - fixedPoint) ratio^(idx - initialIndex)
    ];
    closedForm = shiftedClosedForm
  ];

  <|
    "Detected" -> True,
    "InitialIndex" -> initialIndex,
    "InitialValue" -> initialValue,
    "Ratio" -> ratio,
    "Constant" -> constant,
    "FixedPoint" -> fixedPoint,
    "ClosedForm" -> FullSimplify[closedForm]
  |>
];

OlympiadLinearRecurrenceAnalysis[___] := Missing["NotFirstOrderAffine"];

integerValue[expr_] := Module[{value},
  value = Quiet @ Check[FullSimplify[expr], $Failed];
  If[IntegerQ[value], value, $Failed]
];

matrixPowerMod[
  matrix_?MatrixQ,
  exponent_Integer?NonNegative,
  modulus_Integer?Positive
] := Module[
  {result = IdentityMatrix[Length[matrix]], base = Mod[matrix, modulus], power = exponent},
  While[power > 0,
    If[OddQ[power],
      result = Mod[result.base, modulus]
    ];
    power = Quotient[power, 2];
    If[power > 0,
      base = Mod[base.base, modulus]
    ];
  ];
  result
];

affineValueMod[
  ratio_Integer,
  constant_Integer,
  initialValue_Integer,
  steps_Integer?NonNegative,
  modulus_Integer?Positive
] := Module[{transition, vector},
  transition = {{Mod[ratio, modulus], Mod[constant, modulus]}, {0, 1}};
  vector = matrixPowerMod[transition, steps, modulus].{Mod[initialValue, modulus], 1};
  Mod[First[vector], modulus]
];

findAffinePeriod[
  ratio_Integer,
  constant_Integer,
  initialValue_Integer,
  modulus_Integer?Positive,
  maxStates_Integer?Positive
] := Module[
  {seen = <||>, value = Mod[initialValue, modulus], offset = 0, key},
  While[offset <= maxStates,
    key = ToString[value, InputForm];
    If[KeyExistsQ[seen, key],
      Return @ <|
        "PeriodStartOffset" -> seen[key],
        "PeriodLength" -> offset - seen[key]
      |>
    ];
    seen[key] = offset;
    value = Mod[ratio value + constant, modulus];
    offset++;
  ];
  Missing["PeriodSearchLimit"]
];

analyzeIteratorModularRecurrence[
  form_Association,
  seq_Symbol,
  idx_Symbol,
  modulus_Integer?Positive,
  targetIndex_Integer,
  targetResidue_Integer,
  initialIndex_Integer,
  initialValueInput_,
  maxStates_Integer?Positive
] := Module[
  {
    initialValue, steps, probe, value, offset = 0, seen = <||>,
    values = {}, next, key, period = Missing["PeriodSearchLimit"],
    limit, reducedOffset, valueMod, cycleValues
  },
  initialValue = integerValue[initialValueInput];
  If[initialValue === $Failed,
    Return @ <|
      "Supported" -> False,
      "Message" -> "The initial value must be an integer for modular iteration."
    |>
  ];

  steps = targetIndex - initialIndex;
  If[steps < 0,
    Return @ <|
      "Supported" -> False,
      "Message" -> "The target index must be greater than or equal to the initial index."
    |>
  ];

  probe = form["RightHandSide"] /. form["Previous"] -> Unique["term"];
  If[! FreeQ[probe, idx],
    Return @ <|
      "Supported" -> False,
      "Message" -> "Modular iteration currently supports autonomous first-order recurrences, where the right side does not depend directly on n."
    |>
  ];

  limit = Min[maxStates, modulus + 1];
  value = Mod[initialValue, modulus];

  While[offset <= limit,
    key = ToString[value, InputForm];
    If[KeyExistsQ[seen, key],
      period = <|
        "PeriodStartOffset" -> seen[key],
        "PeriodLength" -> offset - seen[key]
      |>;
      Break[]
    ];
    seen[key] = offset;
    AppendTo[values, value];
    next = integerValue[form["RightHandSide"] /. form["Previous"] -> value];
    If[next === $Failed,
      Return @ <|
        "Supported" -> False,
        "Message" -> "The recurrence did not produce integer values during modular iteration."
      |>
    ];
    value = Mod[next, modulus];
    offset++;
  ];

  If[! AssociationQ[period] && steps >= Length[values],
    Return @ <|
      "Supported" -> False,
      "Message" -> "A modular period was not found within the search limit."
    |>
  ];

  reducedOffset = If[AssociationQ[period] && steps >= period["PeriodStartOffset"],
    period["PeriodStartOffset"] + Mod[
      steps - period["PeriodStartOffset"],
      period["PeriodLength"]
    ],
    steps
  ];

  valueMod = values[[reducedOffset + 1]];
  cycleValues = If[
    AssociationQ[period] && period["PeriodLength"] <= 40,
    Table[
      values[[period["PeriodStartOffset"] + j + 1]],
      {j, 0, period["PeriodLength"] - 1}
    ],
    Missing["CycleTooLong"]
  ];

  <|
    "Supported" -> True,
    "Method" -> "FirstOrderIterator",
    "Modulus" -> modulus,
    "TargetIndex" -> targetIndex,
    "TargetResidue" -> Mod[targetResidue, modulus],
    "Sequence" -> seq,
    "Index" -> idx,
    "InitialIndex" -> initialIndex,
    "InitialValueMod" -> Mod[initialValue, modulus],
    "StepsFromInitial" -> steps,
    "ReducedOffset" -> reducedOffset,
    "ValueMod" -> valueMod,
    "DivisibleQ" -> TrueQ[valueMod == 0],
    "MatchesTargetResidueQ" -> TrueQ[valueMod == Mod[targetResidue, modulus]],
    "Period" -> period,
    "CycleValues" -> cycleValues
  |>
];

Options[AnalyzeModularRecurrence] = {"MaxPeriodStates" -> 100000};

AnalyzeModularRecurrence[
  recurrence_Equal,
  initials_List,
  seq_Symbol,
  idx_Symbol,
  modulusInput_,
  targetIndexInput_,
  targetResidueInput_ : 0,
  OptionsPattern[]
] := Module[
  {
    modulus, targetIndex, targetResidue, analysis, iteratorForm, initial, initialIndex,
    initialValue, ratio, constant, steps, value, period, maxStates,
    reducedOffset, cycleValues
  },
  modulus = integerValue[modulusInput];
  targetIndex = integerValue[targetIndexInput];
  targetResidue = integerValue[targetResidueInput];
  maxStates = OptionValue["MaxPeriodStates"];

  If[modulus === $Failed || modulus <= 0,
    Return @ <|"Supported" -> False, "Message" -> "The modulus must be a positive integer."|>
  ];
  If[targetIndex === $Failed,
    Return @ <|"Supported" -> False, "Message" -> "The target index must be an integer."|>
  ];
  If[targetResidue === $Failed,
    Return @ <|"Supported" -> False, "Message" -> "The target residue must be an integer."|>
  ];

  initial = firstInitialValue[initials, seq];
  If[MissingQ[initial],
    Return @ <|"Supported" -> False, "Message" -> "An integer initial value such as a[0] == 3 is required."|>
  ];
  {initialIndex, initialValue} = initial;

  analysis = OlympiadLinearRecurrenceAnalysis[recurrence, initials, seq, idx];
  If[! AssociationQ[analysis],
    iteratorForm = detectFirstOrderIterator[recurrence, seq, idx];
    If[AssociationQ[iteratorForm],
      Return @ analyzeIteratorModularRecurrence[
        iteratorForm,
        seq,
        idx,
        modulus,
        targetIndex,
        Mod[targetResidue, modulus],
        initialIndex,
        initialValue,
        maxStates
      ]
    ];
    Return @ <|
      "Supported" -> False,
      "Message" -> "Modular solving currently supports first-order integer recurrences."
    |>
  ];

  ratio = integerValue[analysis["Ratio"]];
  constant = integerValue[analysis["Constant"]];
  initialValue = integerValue[initialValue];

  If[MemberQ[{ratio, constant, initialValue}, $Failed],
    Return @ <|
      "Supported" -> False,
      "Message" -> "The recurrence ratio, constant, and initial value must be integers for modular solving."
    |>
  ];

  steps = targetIndex - initialIndex;
  If[steps < 0,
    Return @ <|
      "Supported" -> False,
      "Message" -> "The target index must be greater than or equal to the initial index."
    |>
  ];

  value = affineValueMod[ratio, constant, initialValue, steps, modulus];
  period = If[modulus <= maxStates,
    findAffinePeriod[ratio, constant, initialValue, modulus, modulus + 1],
    Missing["ModulusTooLargeForPeriodSearch"]
  ];

  reducedOffset = If[AssociationQ[period] && steps >= period["PeriodStartOffset"],
    period["PeriodStartOffset"] + Mod[
      steps - period["PeriodStartOffset"],
      period["PeriodLength"]
    ],
    steps
  ];

  cycleValues = If[
    AssociationQ[period] && period["PeriodLength"] <= 40,
    Table[
      affineValueMod[ratio, constant, initialValue, period["PeriodStartOffset"] + j, modulus],
      {j, 0, period["PeriodLength"] - 1}
    ],
    Missing["CycleTooLong"]
  ];

  <|
    "Supported" -> True,
    "Modulus" -> modulus,
    "TargetIndex" -> targetIndex,
    "TargetResidue" -> Mod[targetResidue, modulus],
    "Sequence" -> seq,
    "Index" -> idx,
    "InitialIndex" -> initialIndex,
    "InitialValueMod" -> Mod[initialValue, modulus],
    "RatioMod" -> Mod[ratio, modulus],
    "ConstantMod" -> Mod[constant, modulus],
    "StepsFromInitial" -> steps,
    "ReducedOffset" -> reducedOffset,
    "ValueMod" -> value,
    "DivisibleQ" -> TrueQ[value == 0],
    "MatchesTargetResidueQ" -> TrueQ[value == Mod[targetResidue, modulus]],
    "Period" -> period,
    "CycleValues" -> cycleValues
  |>
];

SampleRecurrenceProblem["PhotoExample"] := <|
  "Name" -> "Photo example",
  "SequenceName" -> "a",
  "IndexName" -> "n",
  "Recurrence" -> "a[n] == 2 a[n - 1] + 5",
  "InitialConditions" -> "a[0] == 3",
  "Range" -> {0, 10}
|>;

SampleRecurrenceProblem["GeometricPlusConstant"] := <|
  "Name" -> "Geometric plus constant",
  "SequenceName" -> "u",
  "IndexName" -> "n",
  "Recurrence" -> "u[n + 1] == 3 u[n] - 4",
  "InitialConditions" -> "u[0] == 2",
  "Range" -> {0, 8}
|>;

SampleRecurrenceProblem["NonlinearSquare"] := <|
  "Name" -> "Nonlinear square",
  "SequenceName" -> "a",
  "IndexName" -> "n",
  "Recurrence" -> "a[n + 1] == a[n] + a[n]^2",
  "InitialConditions" -> "a[1] == 3",
  "Range" -> {0, 10}
|>;

SampleRecurrenceProblem[_] := SampleRecurrenceProblem["PhotoExample"];

SampleModularQuestion["Names"] := {
  "PhotoLastDigit",
  "DivisibleBy7",
  "InvariantRemainder",
  "PeriodModulo11",
  "LastTwoDigits"
};

SampleModularQuestion["PhotoLastDigit"] := Join[
  SampleRecurrenceProblem["PhotoExample"],
  <|
    "Name" -> "Last digit",
    "Question" -> "Find the last digit of a[100].",
    "Modulus" -> 10,
    "TargetIndex" -> 100,
    "TargetResidue" -> 3,
    "ExpectedValueMod" -> 3,
    "ExpectedPeriodLength" -> 4
  |>
];

SampleModularQuestion["DivisibleBy7"] := <|
  "Name" -> "Divisible by 7",
  "Question" -> "Decide whether b[12] is divisible by 7.",
  "SequenceName" -> "b",
  "IndexName" -> "n",
  "Recurrence" -> "b[n] == 2 b[n - 1] + 1",
  "InitialConditions" -> "b[0] == 0",
  "Range" -> {0, 12},
  "Modulus" -> 7,
  "TargetIndex" -> 12,
  "TargetResidue" -> 0,
  "ExpectedValueMod" -> 0,
  "ExpectedPeriodLength" -> 3
|>;

SampleModularQuestion["InvariantRemainder"] := <|
  "Name" -> "Invariant remainder",
  "Question" -> "Find c[25] modulo 9.",
  "SequenceName" -> "c",
  "IndexName" -> "n",
  "Recurrence" -> "c[n] == 5 c[n - 1] + 2",
  "InitialConditions" -> "c[0] == 4",
  "Range" -> {0, 10},
  "Modulus" -> 9,
  "TargetIndex" -> 25,
  "TargetResidue" -> 4,
  "ExpectedValueMod" -> 4,
  "ExpectedPeriodLength" -> 1
|>;

SampleModularQuestion["PeriodModulo11"] := <|
  "Name" -> "Period modulo 11",
  "Question" -> "Use the period modulo 11 to find p[50] modulo 11.",
  "SequenceName" -> "p",
  "IndexName" -> "n",
  "Recurrence" -> "p[n] == 3 p[n - 1] + 4",
  "InitialConditions" -> "p[0] == 2",
  "Range" -> {0, 10},
  "Modulus" -> 11,
  "TargetIndex" -> 50,
  "TargetResidue" -> 2,
  "ExpectedValueMod" -> 2,
  "ExpectedPeriodLength" -> 5
|>;

SampleModularQuestion["LastTwoDigits"] := <|
  "Name" -> "Last two digits",
  "Question" -> "Find the last two digits of s[2026].",
  "SequenceName" -> "s",
  "IndexName" -> "n",
  "Recurrence" -> "s[n] == 10 s[n - 1] + 7",
  "InitialConditions" -> "s[0] == 3",
  "Range" -> {0, 8},
  "Modulus" -> 100,
  "TargetIndex" -> 2026,
  "TargetResidue" -> 77,
  "ExpectedValueMod" -> 77,
  "ExpectedPeriodLength" -> 1
|>;

SampleModularQuestion[_] := SampleModularQuestion["PhotoLastDigit"];

parseNumberSequence[text_String] := Module[{trimmed = StringTrim[text], held, expr},
  If[trimmed === "", Return[Missing["EmptyInput"]]];
  held = parseHeldExpression[
    If[StringStartsQ[trimmed, "{"],
      trimmed,
      "{" <> trimmed <> "}"
    ]
  ];
  If[held === $Failed || MissingQ[held], Return[$Failed]];
  expr = ReleaseHold[held];
  If[
    ListQ[expr] &&
      Length[expr] >= 2 &&
      VectorQ[expr, NumericQ],
    expr,
    $Failed
  ]
];

differenceRows[values_List] :=
  NestList[Differences, values, Length[values] - 1];

constantDifferenceLevel[rows_List] := Module[{usable, pos},
  usable = Most[Rest[rows]];
  pos = FirstPosition[
    usable,
    row_ /; Length[row] > 0 && SameQ @@ row,
    Missing["None"]
  ];
  If[MissingQ[pos], Missing["None"], First[pos]]
];

sequenceFunctionUsableQ[expr_] :=
  expr =!= $Failed &&
    ! MissingQ[expr] &&
    FreeQ[HoldComplete[expr], _FindSequenceFunction];

fitLinearBasisSequence[
  values_List,
  indexes_List,
  basis_List,
  idx_Symbol
] := Module[{coefficients, equations, solution, expr},
  If[Length[values] < Length[basis], Return[Missing["NotEnoughTerms"]]];
  coefficients = Array[Unique["c"] &, Length[basis]];
  equations = Thread[
    Table[
      Sum[
        coefficients[[j]] (basis[[j]] /. idx -> indexes[[i]]),
        {j, 1, Length[basis]}
      ],
      {i, 1, Length[indexes]}
    ] == values
  ];
  solution = Quiet @ Check[Solve[equations, coefficients], {}];
  If[solution === {}, Return[Missing["NoFit"]]];
  expr = FullSimplify[Sum[coefficients[[j]] basis[[j]], {j, 1, Length[basis]}] /. First[solution]];
  If[
    And @@ Table[
      TrueQ[FullSimplify[(expr /. idx -> indexes[[i]]) == values[[i]]]],
      {i, 1, Length[indexes]}
    ],
    expr,
    Missing["NoFit"]
  ]
];

detectSpecialSequenceFunction[
  values_List,
  indexes_List,
  idx_Symbol
] := Module[{models, fitted, k, result = Missing["NoSpecialSequenceModel"]},
  models = {
    <|"Name" -> "alternating plus reciprocal", "Basis" -> {(-1)^idx, 1/idx}|>,
    <|"Name" -> "reciprocal affine", "Basis" -> {1, 1/idx}|>,
    <|"Name" -> "alternating constant", "Basis" -> {1, (-1)^idx}|>,
    <|"Name" -> "alternating reciprocal", "Basis" -> {1, (-1)^idx, 1/idx, (-1)^idx/idx}|>,
    <|"Name" -> "alternating linear", "Basis" -> {1, idx, (-1)^idx, idx (-1)^idx}|>
  };

  Do[
    fitted = fitLinearBasisSequence[values, indexes, models[[k]]["Basis"], idx];
    If[! MissingQ[fitted],
      result = <|"Model" -> models[[k]]["Name"], "Function" -> fitted|>;
      Break[]
    ],
    {k, 1, Length[models]}
  ];

  result
];

linearRecurrenceEquation[coefficients_List, seq_Symbol, idx_Symbol] := Module[{order},
  order = Length[coefficients];
  seq[idx] == Sum[coefficients[[j]] seq[idx - j], {j, 1, order}]
];

predictFromLinearRecurrence[values_List, coefficients_List, count_Integer?NonNegative] :=
  Module[{terms = values, order = Length[coefficients], next},
    If[order == 0 || count == 0, Return[{}]];
    Do[
      next = FullSimplify @ Sum[
        coefficients[[j]] terms[[-j]],
        {j, 1, order}
      ];
      terms = Append[terms, next],
      {count}
    ];
    Take[terms, -count]
  ];

Options[AnalyzeNumberSequence] = {"PredictionCount" -> 5};

AnalyzeNumberSequence[
  sequenceText_String,
  startIndexInput_ : 1,
  OptionsPattern[]
] := Module[
  {
    values, startIndex, predictionCount, idx = Global`n, seq = Global`a,
    rows, diffLevel, coeffs, recurrenceEquation, sequenceFunction, specialFunction,
    sequenceModel,
    knownIndexes, predictedIndexes, predictedByFunction, predictedByRecurrence,
    nextTerms
  },
  values = parseNumberSequence[sequenceText];
  If[values === $Failed,
    Return @ <|
      "Success" -> False,
      "Message" -> "Enter a numeric list such as {1, 1, 2, 3, 5, 8} or 1, 1, 2, 3, 5, 8."
    |>
  ];

  startIndex = integerValue[startIndexInput];
  If[startIndex === $Failed,
    Return @ <|"Success" -> False, "Message" -> "The start index must be an integer."|>
  ];

  predictionCount = OptionValue["PredictionCount"];
  rows = differenceRows[values];
  diffLevel = constantDifferenceLevel[rows];

  coeffs = Quiet @ Check[FindLinearRecurrence[values], $Failed];
  If[! ListQ[coeffs], coeffs = Missing["None"]];
  recurrenceEquation = If[ListQ[coeffs],
    linearRecurrenceEquation[coeffs, seq, idx],
    Missing["None"]
  ];

  knownIndexes = Range[startIndex, startIndex + Length[values] - 1];
  sequenceFunction = Quiet @ Check[
    FullSimplify @ FindSequenceFunction[
      Thread[knownIndexes -> values],
      idx
    ],
    Missing["None"]
  ];
  If[! sequenceFunctionUsableQ[sequenceFunction],
    sequenceFunction = Missing["None"]
  ];

  specialFunction = detectSpecialSequenceFunction[values, knownIndexes, idx];
  If[AssociationQ[specialFunction] && ! sequenceFunctionUsableQ[sequenceFunction],
    sequenceFunction = specialFunction["Function"];
    sequenceModel = specialFunction["Model"],
    sequenceModel = If[AssociationQ[specialFunction], specialFunction["Model"], Missing["None"]]
  ];

  predictedIndexes = Range[
    startIndex + Length[values],
    startIndex + Length[values] + predictionCount - 1
  ];
  predictedByFunction = If[! sequenceFunctionUsableQ[sequenceFunction],
    Missing["None"],
    Quiet @ Check[
      FullSimplify /@ ((sequenceFunction /. idx -> #) & /@ predictedIndexes),
      Missing["None"]
    ]
  ];
  predictedByRecurrence = If[ListQ[coeffs],
    predictFromLinearRecurrence[values, coeffs, predictionCount],
    Missing["None"]
  ];

  nextTerms = Which[
    ListQ[predictedByFunction], Transpose[{predictedIndexes, predictedByFunction}],
    ListQ[predictedByRecurrence], Transpose[{predictedIndexes, predictedByRecurrence}],
    True, {}
  ];

  <|
    "Success" -> True,
    "Values" -> values,
    "StartIndex" -> startIndex,
    "Indexes" -> knownIndexes,
    "DifferenceRows" -> rows,
    "ConstantDifferenceLevel" -> diffLevel,
    "LinearRecurrenceCoefficients" -> coeffs,
    "LinearRecurrenceEquation" -> recurrenceEquation,
    "SequenceModel" -> sequenceModel,
    "SequenceFunction" -> sequenceFunction,
    "PredictedTerms" -> nextTerms
  |>
];

SampleNumberSequence["Names"] := {
  "Fibonacci",
  "Lucas",
  "LinearPredictor",
  "Squares",
  "CubesPlusOne",
  "AlternatingRational"
};

SampleNumberSequence["Fibonacci"] := <|
  "Name" -> "Fibonacci",
  "SequenceText" -> "{1, 1, 2, 3, 5, 8}",
  "StartIndex" -> 1
|>;

SampleNumberSequence["Lucas"] := <|
  "Name" -> "Lucas",
  "SequenceText" -> "{1, 3, 4, 7, 11}",
  "StartIndex" -> 1
|>;

SampleNumberSequence["LinearPredictor"] := <|
  "Name" -> "Linear predictor",
  "SequenceText" -> "{2, 5, 13, 35, 97}",
  "StartIndex" -> 1
|>;

SampleNumberSequence["Squares"] := <|
  "Name" -> "Squares",
  "SequenceText" -> "{1, 4, 9, 16, 25, 36}",
  "StartIndex" -> 1
|>;

SampleNumberSequence["CubesPlusOne"] := <|
  "Name" -> "Cubes plus one",
  "SequenceText" -> "{2, 9, 28, 65, 126}",
  "StartIndex" -> 1
|>;

SampleNumberSequence["AlternatingRational"] := <|
  "Name" -> "Alternating rational",
  "SequenceText" -> "{0, 3/2, -2/3, 5/4, -4/5}",
  "StartIndex" -> 1
|>;

SampleNumberSequence[_] := SampleNumberSequence["Fibonacci"];

appColors = <|
  "Background" -> RGBColor[0.07, 0.075, 0.085],
  "Card" -> RGBColor[0.13, 0.14, 0.15],
  "CardAlt" -> RGBColor[0.17, 0.18, 0.19],
  "Input" -> RGBColor[0.10, 0.11, 0.12],
  "Border" -> RGBColor[0.30, 0.33, 0.36],
  "Text" -> RGBColor[0.94, 0.95, 0.96],
  "Muted" -> RGBColor[0.62, 0.66, 0.70],
  "Accent" -> RGBColor[0.14, 0.46, 0.82],
  "AccentSoft" -> RGBColor[0.10, 0.24, 0.38],
  "Error" -> RGBColor[1.0, 0.32, 0.26],
  "TableHeader" -> RGBColor[0.20, 0.22, 0.24]
|>;

appTitle[text_] :=
  Style[text, 24, Bold, FontFamily -> "Segoe UI", appColors["Text"]];

appSubtitle[text_] :=
  Style[text, 12, FontFamily -> "Segoe UI", appColors["Muted"]];

appSectionTitle[text_] :=
  Style[text, 15, Bold, FontFamily -> "Segoe UI", appColors["Text"]];

appMuted[text_] :=
  Style[text, 11, FontFamily -> "Segoe UI", appColors["Muted"]];

appError[text_] :=
  Style[text, 11, FontFamily -> "Segoe UI", appColors["Error"]];

appLabel[text_] :=
  Style[text, 11, Bold, FontFamily -> "Segoe UI", appColors["Text"]];

appShell[body_] :=
  Framed[
    Pane[body, ImageSize -> {980, Automatic}],
    Background -> appColors["Background"],
    FrameStyle -> None,
    FrameMargins -> 18
  ];

appCard[title_, body_, subtitle_ : None] :=
  Framed[
    Column[
      DeleteCases[
        {
          appSectionTitle[title],
          If[subtitle === None, Nothing, appMuted[subtitle]],
          body
        },
        Nothing
      ],
      Spacings -> 0.85,
      Alignment -> Left
    ],
    Background -> appColors["Card"],
    FrameStyle -> Directive[appColors["Border"], AbsoluteThickness[1]],
    RoundingRadius -> 8,
    FrameMargins -> 14
  ];

SetAttributes[appButton, HoldRest];

appButton[label_, action_, primary_ : False, width_ : Automatic] :=
  Button[
    Style[label, 11, FontFamily -> "Segoe UI", If[primary, White, appColors["Text"]]],
    action,
    Method -> "Queued",
    ImageSize -> width,
    Appearance -> "Palette",
    Background -> If[primary, appColors["Accent"], appColors["CardAlt"]],
    BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11}
  ];

appInput[dynamic_, type_, size_] :=
  InputField[
    dynamic,
    type,
    FieldSize -> size,
    Background -> appColors["Input"],
    BaseStyle -> {FontFamily -> "Consolas", FontSize -> 12, appColors["Text"]}
  ];

appTable[rows_] :=
  Grid[
    rows,
    Frame -> All,
    Alignment -> Center,
    Background -> {None, {appColors["TableHeader"], None}},
    FrameStyle -> Directive[RGBColor[0.48, 0.52, 0.56], AbsoluteThickness[0.8]],
    BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]},
    ItemSize -> All,
    Spacings -> {1.2, 0.7}
  ];

closedFormPanel[result_Association] := Module[
  {seq = result["Sequence"], idx = result["Index"], closed = result["ClosedForm"]},
  appCard[
    "Closed form",
    If[closedFormUsableQ[closed],
      Style[TraditionalForm[seq[idx] == closed], appColors["Text"]],
      appError["RSolve did not return a closed form for this input."]
    ]
  ]
];

olympiadPanel[result_Association] := Module[
  {
    analysis = result["OlympiadAnalysis"], seq = result["Sequence"],
    idx = result["Index"], fixed, fixedSymbol = Global`c
  },
  If[! AssociationQ[analysis],
    Return @ appCard[
      "Olympiad method",
      appMuted["No constant-coefficient first-order affine form was detected. RSolve may still solve it."]
    ]
  ];

  fixed = analysis["FixedPoint"];
  appCard[
    "Olympiad method",
    Column[
    DeleteCases[
      {
        Grid[
          {
            {appLabel["ratio r"], Style[TraditionalForm[analysis["Ratio"]], appColors["Text"]]},
            {appLabel["constant b"], Style[TraditionalForm[analysis["Constant"]], appColors["Text"]]},
            {appLabel["initial value"], Style[TraditionalForm[seq[analysis["InitialIndex"]] == analysis["InitialValue"]], appColors["Text"]]}
          },
          Alignment -> Left,
          Spacings -> {1.2, 0.7},
          BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
        ],
        If[MissingQ[fixed],
          appMuted["Since r = 1, add the same constant each step."],
          Column[
            {
              Row[
                {
                  appMuted["Fixed point: "],
                  Style[TraditionalForm[fixedSymbol == analysis["Ratio"] fixedSymbol + analysis["Constant"]], appColors["Text"]],
                  appMuted[" gives "],
                  Style[TraditionalForm[fixedSymbol == fixed], appColors["Text"]]
                }
              ],
              Row[
                {
                  appMuted["Shifted sequence: "],
                  Style[TraditionalForm[seq[idx] - fixed], appColors["Text"]]
                }
              ]
            },
            Spacings -> 0.5
          ]
        ],
        Row[
          {
            appMuted["fast formula: "],
            Style[TraditionalForm[seq[idx] == analysis["ClosedForm"]], appColors["Text"]]
          }
        ]
      },
      Null
    ],
    Spacings -> 0.8
    ]
  ]
];

termsPanel[result_Association] := Module[
  {terms = result["Terms"], seq = result["Sequence"], idx = result["Index"]},
  appCard[
    "Term table",
    If[terms === {},
      appError["No terms were generated for the selected range."],
      Pane[
        appTable[
          Prepend[
            ({#[[1]], TraditionalForm[#[[2]]]} & /@ terms),
            {appLabel["n"], Style[TraditionalForm[seq[idx]], appColors["Text"]]}
          ]
        ],
        ImageSize -> {900, UpTo[260]},
        Scrollbars -> {False, True}
      ]
    ]
  ]
];

plotPanel[result_Association] := Module[{points},
  points = Cases[result["Terms"], {k_, value_?NumericQ} :> {k, value}];
  If[Length[points] < 2,
    Nothing,
    appCard[
      "Plot",
      ListLinePlot[
        points,
        PlotMarkers -> Automatic,
        PlotTheme -> "Scientific",
        PlotStyle -> appColors["Accent"],
        Background -> appColors["Card"],
        AxesStyle -> appColors["Muted"],
        LabelStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]},
        AxesLabel -> {"n", "value"},
        ImageSize -> 680
      ]
    ]
  ]
];

modularResultPanel[modular_Association] := If[! TrueQ[Lookup[modular, "Supported", False]],
  appCard[
    "Modular answers",
    appMuted[Lookup[modular, "Message", "Solve the recurrence first, then run a modular question."]]
  ],
  Module[
    {
      seq = modular["Sequence"], modulus = modular["Modulus"],
      targetIndex = modular["TargetIndex"], value = modular["ValueMod"],
      targetResidue = modular["TargetResidue"], period = modular["Period"],
      cycleValues = modular["CycleValues"]
    },
    appCard[
      "Modular answers",
      Column[
      {
        Grid[
          {
            {appLabel["target value"], Style[TraditionalForm[seq[targetIndex]], appColors["Text"]], appMuted["mod " <> ToString[modulus]], value},
            {appLabel["divisible by modulus"], "", "", If[modular["DivisibleQ"], "YES", "NO"]},
            {
              appLabel["equals target remainder"],
              "",
              appMuted[ToString[targetResidue]],
              If[modular["MatchesTargetResidueQ"], "YES", "NO"]
            },
            {appLabel["reduced step offset"], "", "", modular["ReducedOffset"]}
          },
          Alignment -> Left,
          Spacings -> {1.1, 0.7},
          BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
        ],
        If[AssociationQ[period],
          Grid[
            {
              {appLabel["eventual period starts at index"], modular["InitialIndex"] + period["PeriodStartOffset"]},
              {appLabel["period length modulo " <> ToString[modulus]], period["PeriodLength"]}
            },
            Alignment -> Left,
            Spacings -> {1.1, 0.7},
            BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
          ],
          appMuted["Period search skipped or exceeded the configured limit."]
        ],
        If[ListQ[cycleValues],
          Row[{appMuted["cycle residues: "], Style[cycleValues, appColors["Text"]]}],
          Nothing
        ]
      },
      Spacings -> 0.8
      ]
    ]
  ]
];

modularResultPanel[_] :=
  appCard["Modular answers", appMuted["Solve the recurrence first, then run a modular question."]];

numberSequenceResultPanel[result_Association] := If[! TrueQ[Lookup[result, "Success", False]],
  appCard[
    "Classifier results",
    appMuted[Lookup[result, "Message", "Enter a number sequence and press Classify."]]
  ],
  Module[
    {
      values = result["Values"], rows = result["DifferenceRows"],
      diffLevel = result["ConstantDifferenceLevel"],
      coefficients = result["LinearRecurrenceCoefficients"],
      recurrenceEquation = result["LinearRecurrenceEquation"],
      sequenceModel = result["SequenceModel"],
      sequenceFunction = result["SequenceFunction"],
      predictedTerms = result["PredictedTerms"], idx = Global`n, seq = Global`a
    },
    appCard[
      "Classifier results",
      Column[
      {
        Grid[
          {
            {appLabel["input length"], Length[values]},
            {appLabel["start index"], result["StartIndex"]},
            {
              appLabel["constant difference level"],
              If[MissingQ[diffLevel], appMuted["none detected"], diffLevel]
            }
          },
          Alignment -> Left,
          Spacings -> {1.2, 0.7},
          BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
        ],
        If[ListQ[coefficients],
          Row[{appMuted["linear recurrence: "], Style[TraditionalForm[recurrenceEquation], appColors["Text"]]}],
          appMuted["linear recurrence: none detected"]
        ],
        If[! MissingQ[sequenceModel],
          Row[{appMuted["detected model: "], Style[sequenceModel, appColors["Text"]]}],
          Nothing
        ],
        If[! MissingQ[sequenceFunction],
          Row[{appMuted["sequence function: "], Style[TraditionalForm[seq[idx] == sequenceFunction], appColors["Text"]]}],
          appMuted["sequence function: none found"]
        ],
        Pane[
          Column[
            Prepend[
              MapIndexed[
                Row[
                  {
                    appLabel[If[First[#2] == 1, "values", "diff " <> ToString[First[#2] - 1]]],
                    appMuted[": "],
                    Style[#1, appColors["Text"]]
                  }
                ] &,
                Take[rows, UpTo[6]]
              ],
              appLabel["difference table"]
            ],
            Spacings -> 0.4
          ],
          ImageSize -> {900, UpTo[160]},
          Scrollbars -> {False, True}
        ],
        If[predictedTerms === {},
          appMuted["next terms: unavailable"],
          Column[
            {
              appLabel["next predicted terms"],
              appTable[Prepend[predictedTerms, {appLabel["n"], appLabel["value"]}]]
            },
            Spacings -> 0.5
          ]
        ]
      },
      Spacings -> 0.8
      ]
    ]
  ]
];

numberSequenceResultPanel[_] :=
  appCard["Classifier results", appMuted["Enter a number sequence and press Classify."]];

resultView[result_Association] := If[! TrueQ[Lookup[result, "Success", False]],
  Panel @ Style[Lookup[result, "Message", "Press Solve to begin."], Darker[Red]],
  Column[
    {
      closedFormPanel[result],
      olympiadPanel[result],
      termsPanel[result],
      plotPanel[result]
    },
    Spacings -> 1
  ]
];

resultView[_] := Panel @ Style["Press Solve to begin.", GrayLevel[0.35]];

RecurrenceOlympiadSolverApp[] := DynamicModule[
  {
    recurrenceText = SampleRecurrenceProblem["PhotoExample"]["Recurrence"],
    initialText = SampleRecurrenceProblem["PhotoExample"]["InitialConditions"],
    sequenceName = SampleRecurrenceProblem["PhotoExample"]["SequenceName"],
    indexName = SampleRecurrenceProblem["PhotoExample"]["IndexName"],
    nmin = 0,
    nmax = 10,
    modulus = 10,
    targetIndex = 100,
    targetResidue = 0,
    result = <|"Success" -> False, "Message" -> "Press Solve to begin."|>,
    modularResult = <|
      "Supported" -> False,
      "Message" -> "Solve the recurrence first, then run a modular question."
    |>,
    sequenceListText = SampleNumberSequence["Fibonacci"]["SequenceText"],
    sequenceStartIndex = SampleNumberSequence["Fibonacci"]["StartIndex"],
    numberSequenceResult = <|
      "Success" -> False,
      "Message" -> "Enter a number sequence and press Classify."
    |>,
    loadSample,
    loadModularSample,
    loadNumberSample
  },
  loadSample[name_] := Module[{sample = SampleRecurrenceProblem[name]},
    recurrenceText = sample["Recurrence"];
    initialText = sample["InitialConditions"];
    sequenceName = sample["SequenceName"];
    indexName = sample["IndexName"];
    {nmin, nmax} = sample["Range"];
    result = <|"Success" -> False, "Message" -> "Press Solve to begin."|>;
    modularResult = <|
      "Supported" -> False,
      "Message" -> "Solve the recurrence first, then run a modular question."
    |>;
  ];

  loadModularSample[name_] := Module[{sample = SampleModularQuestion[name]},
    recurrenceText = sample["Recurrence"];
    initialText = sample["InitialConditions"];
    sequenceName = sample["SequenceName"];
    indexName = sample["IndexName"];
    {nmin, nmax} = sample["Range"];
    modulus = sample["Modulus"];
    targetIndex = sample["TargetIndex"];
    targetResidue = sample["TargetResidue"];
    result = SolveRecurrenceProblem[
      recurrenceText,
      initialText,
      sequenceName,
      indexName,
      "TermRange" -> {nmin, nmax}
    ];
    modularResult = If[
      TrueQ[Lookup[result, "Success", False]],
      AnalyzeModularRecurrence[
        result["Recurrence"],
        result["InitialConditions"],
        result["Sequence"],
        result["Index"],
        modulus,
        targetIndex,
        targetResidue
      ],
      <|"Supported" -> False, "Message" -> Lookup[result, "Message", "The example did not solve."]|>
    ];
  ];

  loadNumberSample[name_] := Module[{sample = SampleNumberSequence[name]},
    sequenceListText = sample["SequenceText"];
    sequenceStartIndex = sample["StartIndex"];
    numberSequenceResult = AnalyzeNumberSequence[
      sequenceListText,
      sequenceStartIndex
    ];
  ];

  appShell @ Column[
    {
      Framed[
        Column[
          {
            appTitle["Recurrence Olympiad Solver"],
            appSubtitle["Closed forms, modular questions, nonlinear iteration, and sequence classification in one workspace."]
          },
          Spacings -> 0.35
        ],
        Background -> appColors["AccentSoft"],
        FrameStyle -> Directive[appColors["Accent"], AbsoluteThickness[1]],
        RoundingRadius -> 10,
        FrameMargins -> 16
      ],
      TabView[
        {
          "Recurrence Solver" -> Column[
            {
              appCard[
                "Recurrence input",
                Grid[
                  {
                    {
                      appLabel["sequence"],
                      appInput[Dynamic[sequenceName], String, 8],
                      appLabel["index"],
                      appInput[Dynamic[indexName], String, 8]
                    },
                    {
                      appLabel["recurrence"],
                      appInput[Dynamic[recurrenceText], String, 62],
                      SpanFromLeft,
                      SpanFromLeft
                    },
                    {
                      appLabel["initial conditions"],
                      appInput[Dynamic[initialText], String, {62, 3}],
                      SpanFromLeft,
                      SpanFromLeft
                    },
                    {
                      appLabel["term range"],
                      Row[
                        {
                          appInput[Dynamic[nmin], Number, 5],
                          Spacer[6],
                          appMuted["to"],
                          Spacer[6],
                          appInput[Dynamic[nmax], Number, 5]
                        }
                      ],
                      SpanFromLeft,
                      SpanFromLeft
                    },
                    {
                      "",
                      Row[
                        {
                          appButton[
                            "Solve",
                            result = SolveRecurrenceProblem[
                              recurrenceText,
                              initialText,
                              sequenceName,
                              indexName,
                              "TermRange" -> {nmin, nmax}
                            ];
                            modularResult = <|
                              "Supported" -> False,
                              "Message" -> "Run a modular question for this solved recurrence."
                            |>,
                            True,
                            120
                          ],
                          Spacer[8],
                          appButton["Photo example", loadSample["PhotoExample"]],
                          Spacer[8],
                          appButton["Affine example", loadSample["GeometricPlusConstant"]],
                          Spacer[8],
                          appButton["Nonlinear example", loadSample["NonlinearSquare"]],
                          Spacer[8],
                          appButton[
                            "Clear",
                            recurrenceText = "";
                            initialText = "";
                            result = <|"Success" -> False, "Message" -> "Press Solve to begin."|>;
                            modularResult = <|
                              "Supported" -> False,
                              "Message" -> "Solve the recurrence first, then run a modular question."
                            |>
                          ]
                        }
                      ],
                      SpanFromLeft,
                      SpanFromLeft
                    }
                  },
                  Alignment -> Left,
                  Spacings -> {1, 0.95},
                  BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
                ]
              ],
              Dynamic @ resultView[result]
            },
            Spacings -> 1.0
          ],
          "Number Sequence" -> Column[
            {
              appCard[
                "Number sequence classifier",
                Grid[
                  {
                    {
                      appLabel["terms"],
                      appInput[Dynamic[sequenceListText], String, 68],
                      SpanFromLeft
                    },
                    {
                      appLabel["start index"],
                      appInput[Dynamic[sequenceStartIndex], Number, 6],
                      SpanFromLeft
                    },
                    {
                      "",
                      Row[
                        {
                          appButton[
                            "Classify",
                            numberSequenceResult = AnalyzeNumberSequence[
                              sequenceListText,
                              sequenceStartIndex
                            ],
                            True,
                            120
                          ],
                          Spacer[8],
                          appButton["Fibonacci", loadNumberSample["Fibonacci"]],
                          Spacer[8],
                          appButton["Lucas", loadNumberSample["Lucas"]],
                          Spacer[8],
                          appButton["Linear predictor", loadNumberSample["LinearPredictor"]],
                          Spacer[8],
                          appButton["Squares", loadNumberSample["Squares"]],
                          Spacer[8],
                          appButton["Cubes + 1", loadNumberSample["CubesPlusOne"]],
                          Spacer[8],
                          appButton["Alt rational", loadNumberSample["AlternatingRational"]],
                          Spacer[8],
                          appButton[
                            "Clear",
                            sequenceListText = "";
                            numberSequenceResult = <|
                              "Success" -> False,
                              "Message" -> "Enter a number sequence and press Classify."
                            |>
                          ]
                        }
                      ],
                      SpanFromLeft
                    }
                  },
                  Alignment -> Left,
                  Spacings -> {1, 0.95},
                  BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
                ]
              ],
              Dynamic @ numberSequenceResultPanel[numberSequenceResult]
            },
            Spacings -> 1.0
          ],
          "Modular Questions" -> Column[
            {
              appCard[
                "Modular example tests",
                Grid[
                  {
                    {
                      appButton["Last digit", loadModularSample["PhotoLastDigit"], False, 135],
                      appButton["Divisible by 7", loadModularSample["DivisibleBy7"], False, 135],
                      appButton["Invariant remainder", loadModularSample["InvariantRemainder"], False, 155]
                    },
                    {
                      appButton["Period modulo 11", loadModularSample["PeriodModulo11"], False, 155],
                      appButton["Last two digits", loadModularSample["LastTwoDigits"], False, 155],
                      SpanFromLeft
                    }
                  },
                  Alignment -> Left,
                  Spacings -> {0.8, 0.75}
                ],
                "Load a modular recurrence example and compute the answer automatically."
              ],
              Dynamic @ If[
                TrueQ[Lookup[result, "Success", False]],
                appCard[
                  "Modular question solver",
                  Column[
                    {
                      Grid[
                        {
                          {
                            appLabel["modulus"],
                            appInput[Dynamic[modulus], Number, 6],
                            appLabel["target index"],
                            appInput[Dynamic[targetIndex], Number, 8],
                            appLabel["test remainder"],
                            appInput[Dynamic[targetResidue], Number, 6]
                          }
                        },
                        Alignment -> Left,
                        Spacings -> {1, 0.8},
                        BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 11, appColors["Text"]}
                      ],
                      Row[
                        {
                          appButton[
                            "Solve modular question",
                            modularResult = AnalyzeModularRecurrence[
                              result["Recurrence"],
                              result["InitialConditions"],
                              result["Sequence"],
                              result["Index"],
                              modulus,
                              targetIndex,
                              targetResidue
                            ],
                            True,
                            180
                          ],
                          Spacer[10],
                          appMuted["Use modulus 10 for last digit; use test remainder 0 for divisibility."]
                        }
                      ]
                    },
                    Spacings -> 0.9
                  ]
                ],
                appCard["Modular question solver", appMuted["Solve a recurrence first, or press one of the modular example buttons."]]
              ],
              Dynamic @ modularResultPanel[modularResult]
            },
            Spacings -> 1.0
          ]
        },
        ImageSize -> {940, Automatic},
        BaseStyle -> {FontFamily -> "Segoe UI", FontSize -> 12, appColors["Text"]}
      ]
    },
    Spacings -> 1.2,
    Alignment -> Left
  ]
];

End[];

EndPackage[];
