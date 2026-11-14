import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/engine/engine_utils.dart';
import 'package:lichess_mobile/src/model/engine/position_evaluator.dart';
import 'package:material_ui/material_ui.dart';

/// A small, optional analysis tool. It never evaluates games on its own: all
/// suggestions are derived from the engine evaluation already used by Lichess.
class const ChesswiseExplanationSheet({
  required final EngineEvaluationFilters filters,
  required final ClientEval? savedEval,
  required final String positionFen,
  super.key,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localEval = ref.watch(engineEvaluationProvider(filters)).eval;
    final eval = pickBestClientEval(localEval: localEval, savedEval: savedEval);

    // A cached or threat-mode evaluation can be for a different position. Never
    // explain a PV that does not start from the position the user requested.
    final validEval = eval != null && eval.position.fen == positionFen && eval.pvs.isNotEmpty
        ? eval
        : null;
    final bestPv = validEval?.pvs.first;
    final bestLine = validEval != null && bestPv != null
        ? bestPv.sanMoves(validEval.position)
        : <String>[];
    final bestMove = bestLine.isEmpty ? null : bestLine.first;
    final alternatePv = validEval != null && validEval.pvs.length > 1
        ? validEval.pvs[1]
        : null;
    final alternateLine = alternatePv != null && validEval != null
        ? alternatePv.sanMoves(validEval.position)
        : <String>[];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFF62B5E7)),
                  const SizedBox(width: 10),
                  Text('Why this move?', style: TextTheme.of(context).titleLarge),
                ],
              ),
              const SizedBox(height: 14),
              if (bestMove == null) ...[
                const Text(
                  'No current engine line is available for this position. '
                  'Turn on Stockfish in Analysis and let it evaluate the position, '
                  'then open this explanation again.',
                ),
              ] else ...[
                Text(
                  '$bestMove  ·  ${bestPv!.evalString}  ·  depth ${validEval!.depth}',
                  style: TextTheme.of(context).titleMedium,
                ),
                const SizedBox(height: 12),
                Text(chesswiseMoveReason(bestMove)),
                const SizedBox(height: 16),
                Text('Stockfish continuation', style: TextTheme.of(context).titleSmall),
                const SizedBox(height: 6),
                SelectableText(bestLine.join('  ')),
                if (alternatePv != null && alternateLine.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Another engine line', style: TextTheme.of(context).titleSmall),
                  const SizedBox(height: 6),
                  Text('${alternateLine.first}  ·  ${alternatePv.evalString}'),
                  Text(alternateLine.join('  ')),
                ],
                const SizedBox(height: 18),
                Text(
                  'Scores and lines can change as Stockfish searches deeper. '
                  'The explanation describes a visible move motif; it does not '
                  'claim to know every reason the engine prefers a move.',
                  style: TextTheme.of(context).bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Only describes a motif we can *observe* from standard algebraic notation.
/// It deliberately avoids inventing tactical/positional advantages.
String chesswiseMoveReason(String san) {
  if (san.endsWith('#')) {
    return 'This move delivers checkmate: the opponent has no legal response to the check.';
  }
  if (san.startsWith('O-O')) {
    return 'This move castles, moving the king and connecting it with a rook. '
        'The engine continuation below is the best way to see why it prefers castling now.';
  }
  if (san.contains('=')) {
    return 'This pawn promotes to another piece. The continuation below shows '
        'how the engine expects the promoted piece to affect the game.';
  }
  if (san.endsWith('+')) {
    return 'This move gives check, forcing your opponent to address the king. '
        'Follow the engine line to see its suggested response.';
  }
  if (san.contains('x')) {
    return 'This move captures a piece or pawn. The continuation below can help '
        'you judge whether the exchange is tactically sound.';
  }
  final destination = RegExp(r'([a-h][1-8])$').firstMatch(san)?.group(1);
  if (destination == 'd4' ||
      destination == 'e4' ||
      destination == 'd5' ||
      destination == 'e5') {
    return 'This move lands on a central square, which may improve central '
        'control. The engine continuation is more reliable than a general rule.';
  }
  return 'Stockfish prefers this move in the current position. Inspect its '
      'continuation below: a trustworthy deeper explanation requires comparing '
      'the specific alternatives, not guessing from notation alone.';
}
