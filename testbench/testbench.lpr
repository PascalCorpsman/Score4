(******************************************************************************)
(* Score4 testbench                                                22.11.2025 *)
(*                                                                            *)
(* Version     : 0.01                                                         *)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* Support     : www.Corpsman.de                                              *)
(*                                                                            *)
(* Description : Testenging to proofe the score4 applications to create       *)
(*               valid outputs.                                               *)
(*                                                                            *)
(* License     : See the file license.md, located under:                      *)
(*  https://github.com/PascalCorpsman/Software_Licenses/blob/main/license.md  *)
(*  for details about the license.                                            *)
(*                                                                            *)
(*               It is not allowed to change or remove this text from any     *)
(*               source file of the project.                                  *)
(*                                                                            *)
(* Warranty    : There is no warranty, neither in correctness of the          *)
(*               implementation, nor anything other that could happen         *)
(*               or go wrong, use at your own risk.                           *)
(*                                                                            *)
(* Known Issues: none                                                         *)
(*                                                                            *)
(* History     : 0.01 - Initial version                                       *)
(*                                                                            *)
(******************************************************************************)
Program testbench;

{$MODE objfpc}{$H+}

Uses sysutils, Classes, process;

Const
  WIDTH = 7;
  HEIGHT = 6;

  ORANGE = 1;
  YELLOW = -1;
  BARREN = 0;
  {.$DEFINE Verbose}// Writeln all calls of dut

Type
  TRunResult = Record
    Move: String; // 0 .. 6, oder ein "WinString"
    ReturnCode: Integer;
  End;

  TRunMode = (rmTest, rmRecord, rmUnknown, rmError);
  TBoard = Array[0..HEIGHT - 1, 0..WIDTH - 1] Of Integer;

Var
  Dut: String; // Filename of DUT or Source
  Testcases: String; // Filename of Testcases
  GamesToPlay: integer; // Number of Games to Play -> only in record mode relevant
  Tests: TStringList; // Tests in Memory ;)
  DutProcess: TProcess;
  Board: TBoard;

Function IfThen(cond: Boolean; TrueVal, FalseVal: String): String;
Begin
  If cond Then
    result := TrueVal
  Else
    result := FalseVal;
End;

Procedure InitDut();
Begin
  DutProcess := TProcess.Create(Nil);
  DutProcess.Executable := dut;
  DutProcess.Parameters.Clear;
  DutProcess.Options := [poWaitOnExit, poUsePipes];
End;

Procedure ClearBoard();
Begin
  FillChar(Board, sizeof(Board), BARREN);
End;

Procedure DropDisk(aSide: Integer; Column: integer; Log: Boolean);
Var
  y: Integer;
Begin
  For y := HEIGHT - 1 Downto 0 Do Begin
    If board[y, column] = BARREN Then Begin
      board[y, column] := aSide;
      break;
    End;
  End;
  If log Then Begin
    tests.add(format('%s%d', [IfThen(aSide = ORANGE, 'o', 'y'), Column]));
  End;
End;

Function RunDut(): TRunResult;
Var
  j, i: Integer;
{$IFDEF Verbose}
  t: String;
{$ENDIF}
  s: String;
  AOutput: TStringList;
Begin
  result.ReturnCode := -1;
  DutProcess.Parameters.Clear;
  // Pass Actual Board as Parameters
{$IFDEF Verbose}
  t := '';
{$ENDIF}
  For j := 0 To HEIGHT - 1 Do
    For i := 0 To WIDTH - 1 Do Begin
      If Board[j, i] <> BARREN Then Begin
        s := ifthen(Board[j, i] = ORANGE, 'o', 'y');
        s := s + format('%d%d', [j, i]);
{$IFDEF Verbose}
        t := t + s + ' ';
{$ENDIF}
        DutProcess.Parameters.Add(s);
      End;
    End;
  DutProcess.Execute;
  AOutput := TStringList.Create;
  AOutput.LoadFromStream(DutProcess.Output);

  result.Move := AOutput[0];
  result.ReturnCode := DutProcess.ExitCode;
{$IFDEF Verbose}
  writeln(trim(t));
  writeln(' ' + result.Move);
{$ENDIF}
  AOutput.Free;
End;

Procedure RunTests();
Var
  gamesDid, testsDid, i: integer;
  s: String;
  p: TRunResult;
Begin
  writeln('Run tests with:');
  writeln('Testcases: ' + Testcases);
  writeln('Target app: ' + Dut);
  InitDut();
  Tests := TStringList.Create;
  Tests.LoadFromFile(Testcases);
  ClearBoard();
  testsDid := 0;
  gamesDid := 0;
  For i := 0 To Tests.Count - 1 Do Begin
    s := tests[i];
    If (s = '') Or (s[1] = '#') Then Continue;
    If length(s) = 2 Then Begin
      Case s[1] Of
        'o': Begin // Unser eigener Zug
            DropDisk(Orange, strtoint(s[2]), false);
          End;
        'y': Begin // Eigentlicher Test
            p := RunDut();
            If p.Move <> s[2] Then Begin
              writeln(format('Failed on Test %d: result is %s, expected %s', [testsDid, p.Move, copy(s, 2, length(s))]));
              halt(1);
            End;
            DropDisk(YELLOW, strtoint(p.Move), false);
          End;
      End;
    End
    Else Begin
      p := RunDut();
      If p.Move <> s Then Begin
        writeln(format('Failed on Test %d: result is %s, expected %s', [testsDid, p.Move, s]));
        halt(1);
      End;
      inc(gamesDid);
      ClearBoard;
    End;
    inc(testsDid);
  End;
  writeln(format('Ran %d tests', [testsDid]));
  writeln(format('Ran %d games', [gamesDid]));
  writeln('');
  writeln('All tests passed.');
  DutProcess.free;
  Tests.free;
End;

Procedure RecordTestGame();
Var
  p: TRunResult;
  Column: Integer;
Begin
  // 1. Board Löschen
  ClearBoard();
  // 2. Spielen bis nichts mehr geht, oder einer gewonnen hat
  // Wir spielen Orange und dürfen in 50 Prozent der Fälle starten
  If random(100) < 50 Then Begin
    DropDisk(ORANGE, random(WIDTH), true);
  End;
  Repeat
    p := RunDut();
    // Warum auch immer der Returncode nicht sauber erkannt wird ...
    If StrToIntDef(p.Move, -1) = -1 Then Begin
      p.ReturnCode := -1;
    End;
    If p.ReturnCode = 0 Then Begin
      // Die Anwendung Spielt
      DropDisk(YELLOW, strtoint(p.Move), true);
      // Wir machen einen Zufälligen, aber Gültigen Zug
      Column := Random(WIDTH);
      While Board[0, Column] <> BARREN Do
        Column := Random(WIDTH);
      DropDisk(ORANGE, Column, true);
    End
    Else Begin
      // Das Spiel ist beendet
      writeln(p.Move);
      Tests.Add(p.Move);
    End;
  Until p.ReturnCode = -1;
End;

Procedure RunRecord();
Var
  i: Integer;
Begin
  writeln('Run record with:');
  writeln('Source app: ' + Dut);
  writeln('Result for testcases: ' + Testcases);
  writeln('Games to emulate: ' + inttostr(GamesToPlay));
  Randomize;
  // RandSeed := 42; -- Enable only for Debugging ;)
  Tests := TStringList.Create;
  InitDut();
  For i := 0 To GamesToPlay - 1 Do Begin
    Writeln(format('# Testgame %d', [i + 1]));
    tests.Add(format('# Testgame %d', [i + 1]));
    RecordTestGame();
  End;
  DutProcess.free;
  writeln(format('Created %d testcases.', [tests.Count - GamesToPlay]));
  tests.SaveToFile(Testcases);
  tests.free;
End;

Function ReadParams(): TRunMode;
Begin
  result := rmUnknown;
  Case ParamCount Of
    2: Begin // Testmode
        Dut := ParamStr(1);
        Testcases := ParamStr(2);
        If (Testcases <> '') And (Not FileExists(Testcases)) Then Begin
          writeln('Error: ' + Testcases + ' not found.');
          exit(rmError);
        End;
        result := rmTest;
      End;
    3: Begin // Record mode
        Dut := ParamStr(1);
        Testcases := ParamStr(2);
        GamesToPlay := strtointdef(ParamStr(3), 0);
        If GamesToPlay <= 0 Then Begin
          writeln('Error, invalid number for games to play.');
          exit(rmError);
        End;
        result := rmRecord;
      End;
  End;
  If (dut <> '') And (Not FileExists(Dut)) Then Begin
    writeln('Error: ' + dut + ' not found.');
    exit(rmError);
  End;
End;

Procedure Printhelp();
Begin
  //       12345678901234567890123456789012345678901234567890123456789012345678901234567890
  writeln('This testbench "proofs", that a given score4 application calculates the correct');
  writeln('values and does not "trick" speedtest by always returning a random number.');
  writeln('');
  writeln('To do so you need to first "record" a trusted version, that then can be');
  writeln('compared to the version to test.');
  writeln('');
  writeln('Record:');
  writeln('To do a record call the application like following:');
  writeln('  testbench <source app filename> <recordfilename> <number of games to record>');
  writeln('');
  writeln('Test:');
  writeln('To do a test call the application like following:');
  writeln('  testbench <test app filename> <recordfilename>');
End;

Begin
  writeln('Score testbench ver. 0.01 by PascalCorpsman');
  Case ReadParams() Of
    rmTest: Begin
        RunTests;
      End;
    rmRecord: Begin
        RunRecord;
      End;
    rmError: Begin
        // Nichts es gab schon eine "ordentliche" Ausgabe ;)
      End
  Else Begin
      Printhelp();
      halt(1);
    End;
  End;
End.

