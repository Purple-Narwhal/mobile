import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/view/offline_computer/chesswise_practice_insight.dart';

void main() {
  test('Nf6 identifies squares the knight really attacks', () {
    final text = chesswisePracticeInsight('Nf6');
    expect(text, contains('e4'));
    expect(text, contains('d5'));
  });

  test('castling is not misclassified as an ordinary king move', () {
    expect(chesswisePracticeInsight('O-O-O'), contains('queenside castling'));
    expect(chesswisePracticeInsight('O-O'), contains('kingside castling'));
  });

  test('capture, mate and promotion have distinct explanations', () {
    expect(chesswisePracticeInsight('Nxe5'), contains('captures material'));
    expect(chesswisePracticeInsight('Qh7#'), contains('checkmate'));
    expect(chesswisePracticeInsight('a8=Q'), contains('promotes'));
  });

  test('good-move alternatives are clearly marked', () {
    expect(chesswisePracticeInsight('Nf3', isAlternative: true), contains('Another reasonable plan'));
  });
}
