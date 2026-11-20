import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds a question with the position *before* the reviewed move.
/// This is intentionally separate from the app's live position.
String practiceCoachQuestion({
  required String positionFen,
  String? playedMoveSan,
  String? suggestedMoveSan,
}) {
  return [
    'Position before my move (FEN): $positionFen',
    if (playedMoveSan != null && playedMoveSan.isNotEmpty)
      'I played: $playedMoveSan',
    if (suggestedMoveSan != null && suggestedMoveSan.isNotEmpty)
      'Stockfish suggested: $suggestedMoveSan',
    'Why is the suggested move stronger in this position? '
        'Show concrete continuations and explain the difference. '
        'Do not assume a tactical advantage without verifying it.',
  ].join('\n');
}

/// An explicit hand-off to the WhyThisMove website.
/// WhyThisMove has no documented third-party explanation API that we can
/// depend on. We never pretend this is an embedded or offline AI response.
class const PracticeCoachSheet({
  required this.positionFen,
  this.playedMoveSan,
  this.suggestedMoveSan,
  super.key,
}) extends StatelessWidget {
  final String positionFen;
  final String? playedMoveSan;
  final String? suggestedMoveSan;

  static final Uri _coachUrl = Uri.parse('https://app.whythismove.com/');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('WhyThisMove', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Understand why the engine prefers a different move. '
              'This opens WhyThisMove in your browser; it does not generate '
              'an explanation inside Lichess.',
            ),
            const SizedBox(height: 12),
            if (playedMoveSan != null)
              Text('Your move: $playedMoveSan'),
            if (suggestedMoveSan != null)
              Text('Engine suggestion: $suggestedMoveSan'),
            const SizedBox(height: 12),
            Text('Position before your move', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(positionFen, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: positionFen));
                  try {
                    final opened = await launchUrl(
                      _coachUrl,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Position copied. Open whythismove.com in a browser.')),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Position copied. Open whythismove.com in a browser.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Copy FEN and open WhyThisMove'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: practiceCoachQuestion(
                      positionFen: positionFen,
                      playedMoveSan: playedMoveSan,
                      suggestedMoveSan: suggestedMoveSan,
                    ),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Question copied to clipboard.')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy a detailed question'),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste the FEN in WhyThisMove, then ask about the move. '
              'The website may require an account and its own credits. '
              'Your position is only sent there if you choose to paste it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
