import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/view/offline_computer/practice_coach_sheet.dart';

void main() {
  test('keeps the original position and distinguishes two moves', () {
    final question = practiceCoachQuestion(
      positionFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      playedMoveSan: 'a3',
      suggestedMoveSan: 'e4',
    );
    expect(question, contains('Position before my move (FEN):'));
    expect(question, contains('I played: a3'));
    expect(question, contains('Stockfish suggested: e4'));
    expect(question, contains('Show concrete continuations'));
  });

  test('does not invent played or suggested moves when unavailable', () {
    final question = practiceCoachQuestion(
      positionFen: '8/8/8/8/8/8/8/8 w - - 0 1',
    );
    expect(question, isNot(contains('I played:')));
    expect(question, isNot(contains('Stockfish suggested:')));
  });
}
