projectDirectory = DirectoryName[DirectoryName[$InputFileName]];
statusFile = FileNameJoin[{projectDirectory, "Tests", "SmokeTest.out"}];

fail[message_] := (
  Export[statusFile, message, "Text"];
  Quit[1]
);

Get[FileNameJoin[{projectDirectory, "Kernel", "RecurrenceOlympiadSolver.wl"}]];

result = RecurrenceOlympiadSolver`SolveRecurrenceProblem[
  "a[n] == 2 a[n - 1] + 5",
  "a[0] == 3",
  "a",
  "n",
  "TermRange" -> {0, 5}
];

expectedClosedForm = -5 + 8 2^Global`n;
expectedTerms = {{0, 3}, {1, 11}, {2, 27}, {3, 59}, {4, 123}, {5, 251}};

If[! TrueQ[result["Success"]],
  fail["FAIL: solver did not report success"]
];

If[! TrueQ[FullSimplify[result["ClosedForm"] == expectedClosedForm]],
  fail["FAIL: wrong closed form: " <> ToString[result["ClosedForm"], InputForm]]
];

If[result["Terms"] =!= expectedTerms,
  fail["FAIL: wrong terms: " <> ToString[result["Terms"], InputForm]]
];

If[! AssociationQ[result["OlympiadAnalysis"]],
  fail["FAIL: olympiad analysis was not detected"]
];

modular = RecurrenceOlympiadSolver`AnalyzeModularRecurrence[
  result["Recurrence"],
  result["InitialConditions"],
  result["Sequence"],
  result["Index"],
  10,
  100,
  3
];

If[! TrueQ[modular["Supported"]],
  fail["FAIL: modular solver did not support the photo recurrence: " <> modular["Message"]]
];

If[modular["ValueMod"] =!= 3,
  fail["FAIL: expected a[100] mod 10 to be 3, got " <> ToString[modular["ValueMod"], InputForm]]
];

If[! TrueQ[modular["MatchesTargetResidueQ"]],
  fail["FAIL: expected target remainder test to pass"]
];

If[! AssociationQ[modular["Period"]] || modular["Period"]["PeriodLength"] =!= 4,
  fail["FAIL: expected period length 4 modulo 10, got " <> ToString[modular["Period"], InputForm]]
];

checkModularExample[name_] := Module[{sample, sampleResult, sampleModular},
  sample = RecurrenceOlympiadSolver`SampleModularQuestion[name];
  sampleResult = RecurrenceOlympiadSolver`SolveRecurrenceProblem[
    sample["Recurrence"],
    sample["InitialConditions"],
    sample["SequenceName"],
    sample["IndexName"],
    "TermRange" -> sample["Range"]
  ];

  If[! TrueQ[sampleResult["Success"]],
    fail["FAIL: example " <> name <> " did not solve"]
  ];

  sampleModular = RecurrenceOlympiadSolver`AnalyzeModularRecurrence[
    sampleResult["Recurrence"],
    sampleResult["InitialConditions"],
    sampleResult["Sequence"],
    sampleResult["Index"],
    sample["Modulus"],
    sample["TargetIndex"],
    sample["TargetResidue"]
  ];

  If[! TrueQ[sampleModular["Supported"]],
    fail["FAIL: modular example " <> name <> " unsupported: " <> sampleModular["Message"]]
  ];

  If[sampleModular["ValueMod"] =!= sample["ExpectedValueMod"],
    fail[
      "FAIL: modular example " <> name <> " expected value " <>
        ToString[sample["ExpectedValueMod"], InputForm] <> ", got " <>
        ToString[sampleModular["ValueMod"], InputForm]
    ]
  ];

  If[! TrueQ[sampleModular["MatchesTargetResidueQ"]],
    fail["FAIL: modular example " <> name <> " target residue check failed"]
  ];

  If[
    ! AssociationQ[sampleModular["Period"]] ||
      sampleModular["Period"]["PeriodLength"] =!= sample["ExpectedPeriodLength"],
    fail[
      "FAIL: modular example " <> name <> " expected period " <>
        ToString[sample["ExpectedPeriodLength"], InputForm] <> ", got " <>
        ToString[sampleModular["Period"], InputForm]
    ]
  ];
];

Scan[checkModularExample, RecurrenceOlympiadSolver`SampleModularQuestion["Names"]];

nonlinear = RecurrenceOlympiadSolver`SolveRecurrenceProblem[
  "a[n + 1] == a[n] + a[n]^2",
  "a[1] == 3",
  "a",
  "n",
  "TermRange" -> {0, 5}
];

expectedNonlinearTerms = {
  {1, 3},
  {2, 12},
  {3, 156},
  {4, 24492},
  {5, 599882556}
};

If[! TrueQ[nonlinear["Success"]],
  fail["FAIL: nonlinear screenshot recurrence did not solve"]
];

If[nonlinear["Terms"] =!= expectedNonlinearTerms,
  fail[
    "FAIL: nonlinear screenshot terms were wrong: " <>
      ToString[nonlinear["Terms"], InputForm]
  ]
];

nonlinearModular = RecurrenceOlympiadSolver`AnalyzeModularRecurrence[
  nonlinear["Recurrence"],
  nonlinear["InitialConditions"],
  nonlinear["Sequence"],
  nonlinear["Index"],
  10,
  100,
  2
];

If[! TrueQ[nonlinearModular["Supported"]],
  fail["FAIL: nonlinear modular solver did not support screenshot recurrence: " <> nonlinearModular["Message"]]
];

If[nonlinearModular["ValueMod"] =!= 2,
  fail[
    "FAIL: expected nonlinear a[100] mod 10 to be 2, got " <>
      ToString[nonlinearModular["ValueMod"], InputForm]
  ]
];

If[
  ! AssociationQ[nonlinearModular["Period"]] ||
    nonlinearModular["Period"]["PeriodStartOffset"] =!= 1 ||
    nonlinearModular["Period"]["PeriodLength"] =!= 2,
  fail[
    "FAIL: expected nonlinear period start 1 and length 2, got " <>
      ToString[nonlinearModular["Period"], InputForm]
  ]
];

checkNumberSequence[name_, expectedCoefficients_, expectedFirstPrediction_, expectedDiffLevel_] := Module[
  {sample, analysis, predictions},
  sample = RecurrenceOlympiadSolver`SampleNumberSequence[name];
  analysis = RecurrenceOlympiadSolver`AnalyzeNumberSequence[
    sample["SequenceText"],
    sample["StartIndex"]
  ];

  If[! TrueQ[analysis["Success"]],
    fail["FAIL: number sequence example " <> name <> " did not analyze"]
  ];

  If[
    ListQ[expectedCoefficients] &&
      analysis["LinearRecurrenceCoefficients"] =!= expectedCoefficients,
    fail[
      "FAIL: number sequence example " <> name <> " expected coefficients " <>
        ToString[expectedCoefficients, InputForm] <> ", got " <>
        ToString[analysis["LinearRecurrenceCoefficients"], InputForm]
    ]
  ];

  predictions = analysis["PredictedTerms"];
  If[predictions === {} || predictions[[1, 2]] =!= expectedFirstPrediction,
    fail[
      "FAIL: number sequence example " <> name <> " expected first prediction " <>
        ToString[expectedFirstPrediction, InputForm] <> ", got " <>
        ToString[predictions, InputForm]
    ]
  ];

  If[
    expectedDiffLevel =!= Automatic &&
      analysis["ConstantDifferenceLevel"] =!= expectedDiffLevel,
    fail[
      "FAIL: number sequence example " <> name <> " expected difference level " <>
        ToString[expectedDiffLevel, InputForm] <> ", got " <>
        ToString[analysis["ConstantDifferenceLevel"], InputForm]
    ]
  ];
];

checkNumberSequence["Fibonacci", {1, 1}, 13, Automatic];
checkNumberSequence["Lucas", {1, 1}, 18, Automatic];
checkNumberSequence["LinearPredictor", {5, -6}, 275, Automatic];
checkNumberSequence["Squares", Automatic, 49, 2];
checkNumberSequence["CubesPlusOne", Automatic, 217, 3];

alternatingRational = RecurrenceOlympiadSolver`AnalyzeNumberSequence[
  "0, 3/2, -2/3, 5/4, -4/5",
  1
];

If[! TrueQ[alternatingRational["Success"]],
  fail["FAIL: alternating rational sequence did not analyze"]
];

If[
  ! TrueQ[
    FullSimplify[
      alternatingRational["SequenceFunction"] ==
        (-1)^Global`n + 1/Global`n
    ]
  ],
  fail[
    "FAIL: alternating rational formula was wrong: " <>
      ToString[alternatingRational["SequenceFunction"], InputForm]
  ]
];

If[
  alternatingRational["PredictedTerms"] === {} ||
    alternatingRational["PredictedTerms"][[1]] =!= {6, 7/6},
  fail[
    "FAIL: alternating rational first prediction was wrong: " <>
      ToString[alternatingRational["PredictedTerms"], InputForm]
  ]
];

appExpression = Quiet @ Check[
  RecurrenceOlympiadSolver`RecurrenceOlympiadSolverApp[],
  $Failed
];

If[appExpression === $Failed,
  fail["FAIL: app expression did not construct"]
];

Export[
  statusFile,
  "PASS: photo recurrence gives " <> ToString[result["ClosedForm"], InputForm] <>
    ", all modular examples passed, nonlinear iteration works, and sequence classifier works",
  "Text"
];
Quit[0]
