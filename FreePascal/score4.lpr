Program score4;

{$MODE objfpc}{$H+}

Uses
  SysUtils;

Const
  WIDTH = 7;
  HEIGHT = 6;

  ORANGE_WINS = 1000000;
  YELLOW_WINS = -1000000;

  ORANGE = 1;
  YELLOW = -1;
  BARREN = 0;

Var
  g_maxDepth: Integer = 7;
  g_debug: Integer = 0;

Type
  TBoard = Array[0..HEIGHT - 1, 0..WIDTH - 1] Of Integer;

Function IfThen(cond: Boolean; TrueVal, FalseVal: integer): integer;
Begin
  If cond Then
    result := TrueVal
  Else
    result := FalseVal;
End;

Function Inside(y, x: Integer): Boolean;
Begin
  Result := (y >= 0) And (y < HEIGHT) And (x >= 0) And (x < WIDTH);
End;


Function ScoreBoard(Const scores: TBoard): Integer;
Var
  counters: Array[0..8] Of Integer;
  x, y, score, idx: Integer;
Begin
  FillChar(counters, SizeOf(counters), 0);

  // Horizontal spans
  For y := 0 To HEIGHT - 1 Do Begin
    score := scores[y][0] + scores[y][1] + scores[y][2];
    For x := 3 To WIDTH - 1 Do Begin
      score := score + scores[y][x];
      Inc(counters[score + 4]);
      score := score - scores[y][x - 3];
    End;
  End;

  // Vertical spans
  For x := 0 To WIDTH - 1 Do Begin
    score := scores[0][x] + scores[1][x] + scores[2][x];
    For y := 3 To HEIGHT - 1 Do Begin
      score := score + scores[y][x];
      Inc(counters[score + 4]);
      score := score - scores[y - 3][x];
    End;
  End;

  // Down-right diagonals
  For y := 0 To HEIGHT - 4 Do
    For x := 0 To WIDTH - 4 Do Begin
      score := 0;
      For idx := 0 To 3 Do
        score := score + scores[y + idx][x + idx];
      Inc(counters[score + 4]);
    End;

  // Up-right diagonals
  For y := 3 To HEIGHT - 1 Do
    For x := 0 To WIDTH - 4 Do Begin
      score := 0;
      For idx := 0 To 3 Do
        score := score + scores[y - idx][x + idx];
      Inc(counters[score + 4]);
    End;

  If counters[0] <> 0 Then
    Result := YELLOW_WINS
  Else If counters[8] <> 0 Then
    Result := ORANGE_WINS
  Else
    Result :=
      counters[5] + 2 * counters[6] + 5 * counters[7] -
      counters[3] - 2 * counters[2] - 5 * counters[1];
End;


Function DropDisk(Var board: TBoard; column, color: Integer): Integer;
Var
  y: Integer;
Begin
  For y := HEIGHT - 1 Downto 0 Do Begin
    If board[y][column] = BARREN Then Begin
      board[y][column] := color;
      Exit(y);
    End;
  End;
  Result := -1;
End;


Procedure LoadBoard(argc: Integer; Var board: TBoard);
Var
  i: Integer;
  arg: String;
Begin
  For i := 1 To ParamCount Do Begin
    arg := ParamStr(i);
    If (Length(arg) >= 3) And ((arg[1] = 'o') Or (arg[1] = 'y')) Then Begin
      board[Ord(arg[2]) - Ord('0')][Ord(arg[3]) - Ord('0')] :=
        IfThen(arg[1] = 'o', ORANGE, YELLOW);
    End
    Else If arg = '-debug' Then
      g_debug := 1
    Else If arg = '-level' Then
      g_maxDepth := StrToInt(StrPas(argv[i + 1]));
  End;
End;

Procedure abMinimax(
  maximize: Integer;
  color: Integer;
  depth: Integer;
  Var board: TBoard;
  Out move: Integer;
  Out score: Integer
  );
Var
  bestScore, bestMove: Integer;
  column: Integer;
  rowFilled: Integer;
  s: Integer;
  moveInner, scoreInner: Integer;
  newColor: Integer;
Begin
  If maximize <> 0 Then
    bestScore := -10000000
  Else
    bestScore := 10000000;

  bestMove := -1;

  For column := 0 To WIDTH - 1 Do Begin
    If board[0][column] <> BARREN Then
      continue;

    rowFilled := DropDisk(board, column, color);
    If rowFilled = -1 Then
      continue;

    s := ScoreBoard(board);

    If s = IfThen(maximize <> 0, ORANGE_WINS, YELLOW_WINS) Then Begin
      bestMove := column;
      bestScore := s;
      board[rowFilled][column] := BARREN;
      break;
    End;

    If depth > 1 Then Begin
      If color = ORANGE Then
        newColor := YELLOW
      Else
        newColor := ORANGE;
      abMinimax(Ord(maximize = 0), newColor, depth - 1, board, moveInner, scoreInner);
    End
    Else Begin
      moveInner := -1;
      scoreInner := s;
    End;

    board[rowFilled][column] := BARREN;

    If (scoreInner = ORANGE_WINS) Or (scoreInner = YELLOW_WINS) Then
      scoreInner := scoreInner - depth * color;

    If (depth = g_maxDepth) And (g_debug <> 0) Then
      WriteLn('Depth ', depth, ', placing on ', column, ', score: ', scoreInner);

    If maximize <> 0 Then Begin
      If (scoreInner >= bestScore) Then Begin
        bestScore := scoreInner;
        bestMove := column;
      End;
    End
    Else Begin
      If (scoreInner <= bestScore) Then Begin
        bestScore := scoreInner;
        bestMove := column;
      End;
    End;
  End;

  move := bestMove;
  score := bestScore;
End;


Var
  board: TBoard;
  scoreOrig: Integer;
  move, score: Integer;

Begin
  FillChar(board, SizeOf(board), 0);

  LoadBoard(ParamCount + 1, board);

  scoreOrig := ScoreBoard(board);

  If scoreOrig = ORANGE_WINS Then Begin
    WriteLn('I win');
    Halt(-1);
  End
  Else If scoreOrig = YELLOW_WINS Then Begin
    WriteLn('You win');
    Halt(-1);
  End
  Else Begin
    abMinimax(1, ORANGE, g_maxDepth, board, move, score);

    If move <> -1 Then Begin
      WriteLn(move);
      DropDisk(board, move, ORANGE);
      scoreOrig := ScoreBoard(board);

      If scoreOrig = ORANGE_WINS Then Begin
        WriteLn('I win');
        Halt(-1);
      End
      Else If scoreOrig = YELLOW_WINS Then Begin
        WriteLn('You win');
        Halt(-1);
      End
      Else
        Halt(0);
    End
    Else Begin
      WriteLn('No move possible');
      Halt(-1);
    End;
  End;
End.

