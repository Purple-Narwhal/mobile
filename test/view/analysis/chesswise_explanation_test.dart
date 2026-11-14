import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/view/analysis/chesswise_explanation_sheet.dart';

void main() {
  test('checkmate explanation is only attached to mate notation', () {
    expect(chesswiseMoveReason('Qh7#'), contains('checkmate'));
    expect(chesswiseMoveReason('Qh7+'), isNot(contains('checkmate')));
  });

  test('promotion and capture motifs are recognized', () {
    expect(chesswiseMoveReason('e8=Q'), contains('promotes'));
    expect(chesswiseMoveReason('Nxe5'), contains('captures'));
  });

  test('unclassified moves do not claim a made-up tactical reason', () {
    expect(chesswiseMoveReason('Nf3'), contains('requires comparing'));
  });
}
