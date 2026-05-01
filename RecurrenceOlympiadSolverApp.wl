projectDirectory =
  If[StringQ[$InputFileName] && $InputFileName =!= "",
    DirectoryName[$InputFileName],
    NotebookDirectory[]
  ];

Get[FileNameJoin[{projectDirectory, "Kernel", "RecurrenceOlympiadSolver.wl"}]];

CreateDocument[
  RecurrenceOlympiadSolver`RecurrenceOlympiadSolverApp[],
  WindowTitle -> "Recurrence Olympiad Solver",
  Saveable -> True
]
