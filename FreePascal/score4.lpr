Program score4;

{$INLINE ON}
{$MODE DELPHI} // bessere Pointerarithmetik
{$R-,Q-,S-} // Range-, Overflow-, Stack-Checks aus

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

Function ScoreBoard(Const scores: TBoard): Integer;
Const
  // Konstanten sind bereits gegeben, WIDTH=7, HEIGHT=6
  DIAG_DR_STEP = WIDTH + 1; // down-right step in linearized array
  DIAG_UR_STEP = -WIDTH + 1; // up-right step in linearized array
Var
  base: PInteger; // pointer auf scores[0][0]
  counters: Array[0..8] Of Integer;
  y, x: Integer;
  score: Integer;
  p, q, r: PInteger;
  diagStep: Integer;
Begin
  // zero counters fast
  FillChar(counters, SizeOf(counters), 0);

  // base pointer auf erstes Element
  base := @scores[0][0];

  // ---------------------------
  // Horizontal rolling windows
  // ---------------------------
  For y := 0 To HEIGHT - 1 Do Begin
    // p zeigt auf scores[y][0]
    p := base + (y * WIDTH);
    // initial 3-sum (positions 0,1,2)
    score := p[0] + p[1] + p[2];
    // slide window along row: add p[x] (x from 3..WIDTH-1), remove p[x-3]
    For x := 3 To WIDTH - 1 Do Begin
      score := score + p[x];
      Inc(counters[score + 4]);
      score := score - p[x - 3];
    End;
  End;

  // ---------------------------
  // Vertical rolling windows
  // ---------------------------
  // For each column, p starts at base + x (row 0) and we step by WIDTH to go down
  For x := 0 To WIDTH - 1 Do Begin
    p := base + x; // points to [0,x]
    // initial sum of first 3 rows in this column: rows 0,1,2
    score := p[0] + p[WIDTH] + p[2 * WIDTH];
    q := p + 3 * WIDTH; // q points to row 3 in this column
    For y := 3 To HEIGHT - 1 Do Begin
      score := score + q^; // add current row y
      Inc(counters[score + 4]);
      score := score - p^; // remove oldest (row y-3)
      Inc(p, WIDTH); // move p to next row (oldest+1)
      Inc(q, WIDTH); // move q to next row (current+1)
    End;
  End;

  // ---------------------------
  // Down-right diagonals ( \ )
  // Only start positions where a length-4 diagonal fits:
  // y in [0..HEIGHT-4], x in [0..WIDTH-4]
  // ---------------------------
  diagStep := DIAG_DR_STEP;
  For y := 0 To HEIGHT - 4 Do
    For x := 0 To WIDTH - 4 Do Begin
      p := base + (y * WIDTH + x);
      // load four diagonal elements at offsets 0, diagStep, 2*diagStep, 3*diagStep
      score := p[0] + p[diagStep] + p[2 * diagStep] + p[3 * diagStep];
      Inc(counters[score + 4]);
    End;

  // ---------------------------
  // Up-right diagonals ( / )
  // Start positions: y in [3..HEIGHT-1], x in [0..WIDTH-4]
  // step is (-WIDTH + 1)
  // ---------------------------
  diagStep := DIAG_UR_STEP;
  For y := 3 To HEIGHT - 1 Do
    For x := 0 To WIDTH - 4 Do Begin
      p := base + (y * WIDTH + x);
      // offsets: 0, diagStep, 2*diagStep, 3*diagStep (diagStep negative)
      score := p[0] + p[diagStep] + p[2 * diagStep] + p[3 * diagStep];
      Inc(counters[score + 4]);
    End;

  // ---------------------------
  // Schnellcheck auf sofortigen Sieg (early returns)
  // counters[0] corresponds to score = -4 (YELLOW), counters[8] to +4 (ORANGE)
  // ---------------------------
  If counters[0] <> 0 Then Begin
    Result := YELLOW_WINS;
    Exit;
  End;

  If counters[8] <> 0 Then Begin
    Result := ORANGE_WINS;
    Exit;
  End;

  // Heuristik: gleiche wie vorher
  Result := counters[5] + 2 * counters[6] + 5 * counters[7]
    - counters[3] - 2 * counters[2] - 5 * counters[1];
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

(*
 * Dieser Code liest die Parameter der Anwendung aus und initialisiert damit das
 * Board.
 * Es finden so gut wie keine Checks statt, alle Parameter müssen also alle der
 * Form: "pcr" sein mit
 *   p in [ 'o', 'y' ]
 *   c in [ 0 .. 5 ]
 *   r in [ 0 .. 6 ]
 *)

Procedure LoadBoard(Var board: TBoard);
Var
  i: Integer;
  arg: String;
Begin
  For i := 1 To ParamCount Do Begin
    arg := ParamStr(i);
    If (Length(arg) >= 3) And ((arg[1] = 'o') Or (arg[1] = 'y')) Then Begin
      If arg[1] = 'o' Then Begin
        board[Ord(arg[2]) - Ord('0')][Ord(arg[3]) - Ord('0')] := ORANGE;
      End
      Else Begin
        board[Ord(arg[2]) - Ord('0')][Ord(arg[3]) - Ord('0')] := YELLOW;
      End;
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
  s, t: Integer;
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
    If maximize <> 0 Then
      t := ORANGE_WINS
    Else
      t := YELLOW_WINS;
    If s = t Then Begin
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
  FillChar(board, SizeOf(board), BARREN);

  LoadBoard(board);

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

