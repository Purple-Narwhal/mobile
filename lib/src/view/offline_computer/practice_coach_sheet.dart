import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/engine/practice_comment.dart';
import 'package:lichess_mobile/src/model/offline_computer/practice_coach_engine.dart';
import 'package:material_ui/material_ui.dart';

/// In-app, offline Practice teaching built from verified board facts and
/// Stockfish's own principal variations. Nothing leaves the device.
class const PracticeCoachSheet({
  required this.before,
  required this.played,
  required this.verdict,
  this.suggested,
  this.beforeEval,
  this.afterEval,
  super.key,
}) extends StatelessWidget {
  final Position before;
  final SanMove played;
  final SanMove? suggested;
  final MoveVerdict verdict;
  final ClientEval? beforeEval;
  final ClientEval? afterEval;

  @override
  Widget build(BuildContext context) {
    final report = buildPracticeCoachReport(
      before: before,
      played: played,
      suggested: suggested,
      verdict: verdict,
      beforeEval: beforeEval,
      afterEval: afterEval,
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Move insight', style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('You played ${played.san}', style: theme.textTheme.bodyMedium),
                if (suggested != null)
                  Text('·  Engine: ${suggested!.san}', style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 18),
            Text(report.heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(report.explanation),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 18),
                      const SizedBox(width: 8),
                      Text('Think like a coach', style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(report.question),
                ],
              ),
            ),
            if (report.bestLine.isNotEmpty || report.playedLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Show the engine continuations'),
                subtitle: Text(
                  report.depth == null
                      ? report.confidence
                      : '${report.confidence} · depth ${report.depth}',
                  style: theme.textTheme.bodySmall,
                ),
                children: [
                  if (report.bestLine.isNotEmpty)
                    _Variation(
                      title: 'Suggested continuation',
                      moves: report.bestLine,
                    ),
                  if (report.playedLine.isNotEmpty)
                    _Variation(
                      title: 'After your move',
                      moves: report.playedLine,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(report.confidence, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(
              'The coach describes chess facts visible in the position and available '
              'engine lines. Positional clues are not proof that a move is best; '
              'engine evaluations and variations can change with deeper search.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class const _Variation({required this.title, required this.moves}) extends StatelessWidget {
  final String title;
  final List<String> moves;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(moves.take(6).join('  ')),
        ],
      ),
    );
  }
}
