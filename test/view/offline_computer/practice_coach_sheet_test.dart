import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/engine/practice_comment.dart';
import 'package:lichess_mobile/src/model/offline_computer/practice_coach_engine.dart';

void main() {
  final start = Variant.standard.initialPosition;
  SanMove move(Position position, String uci) {
    final parsed = Move.parse(uci)!;
    final result = position.makeSanUnchecked(parsed);
    return SanMove(result.$2, parsed);
  }

  test('no invented tactical explanation without a real line', () {
    final report = buildPracticeCoachReport(
      before: start,
      played: move(start, 'a2a3'),
      suggested: move(start, 'e2e4'),
      verdict: MoveVerdict.blunder,
    );
    expect(report.confidence, 'Limited evidence');
    expect(report.heading, contains('different continuation'));
    expect(report.bestLine, ['e4']);
    expect(report.playedLine, ['a3']);
  });

  test('legal principal variation is replayed into SAN', () {
    final eval = LocalEval(
      position: start,
      depth: 18,
      nodes: 10000,
      millis: 1000,
      searchTime: const Duration(seconds: 1),
      threatMode: false,
      pvs: [
        PvData(moves: ['e2e4', 'e7e5', 'g1f3'].lock, cp: 35),
        PvData(moves: ['a2a3', 'e7e5'].lock, cp: -70),
      ].lock,
    );
    final report = buildPracticeCoachReport(
      before: start,
      played: move(start, 'a2a3'),
      suggested: move(start, 'e2e4'),
      verdict: MoveVerdict.inaccuracy,
      beforeEval: eval,
    );
    expect(report.bestLine, ['e4', 'e5', 'Nf3']);
    expect(report.playedLine, ['a3', 'e5']);
    expect(report.depth, 18);
  });

  test('stale evaluation does not supply a false variation', () {
    final otherPosition = start.makeSanUnchecked(Move.parse('e2e4')!).$1;
    final stale = LocalEval(
      position: otherPosition,
      depth: 18,
      nodes: 10000,
      millis: 1000,
      searchTime: const Duration(seconds: 1),
      threatMode: false,
      pvs: [PvData(moves: ['e7e5'].lock, cp: 0)].lock,
    );
    final report = buildPracticeCoachReport(
      before: start,
      played: move(start, 'a2a3'),
      suggested: move(start, 'e2e4'),
      verdict: MoveVerdict.mistake,
      beforeEval: stale,
    );
    expect(report.depth, isNull);
    expect(report.bestLine, ['e4']);
  });

  test('good moves receive advice without being called a blunder', () {
    final report = buildPracticeCoachReport(
      before: start,
      played: move(start, 'e2e4'),
      verdict: MoveVerdict.goodMove,
    );
    expect(report.heading, 'Your move holds up');
    expect(report.confidence, 'Limited evidence');
  });
}
