/// A conservative, offline-first first step for move explanations.
///
/// The caller supplies the SAN of the move *already* suggested by Lichess.
/// We do not change Lichess's engine score or move classification.
/// These observations describe directly inferable move ideas, not a proof
/// that the suggested move is uniquely best. Position-aware analysis with
/// compared principal variations belongs to a later update.
String chesswisePracticeInsight(String san, {bool isAlternative = false}) {
  final prefix = isAlternative
      ? 'Another reasonable plan: '
      : 'A useful idea behind the suggestion: ';

  if (san.endsWith('#')) {
    return '${prefix}this move delivers checkmate, so the opponent has no legal response to the check.';
  }
  if (san.startsWith('O-O-O')) {
    return '${prefix}queenside castling moves the king away from the center and activates the rook. Whether it is safer here depends on the position.';
  }
  if (san.startsWith('O-O')) {
    return '${prefix}kingside castling moves the king away from the center and activates the rook. King safety still depends on the position.';
  }
  if (san.contains('=')) {
    return '${prefix}the pawn promotes, creating a more powerful piece. The chosen promotion can change the tactical outcome.';
  }
  if (san.endsWith('+')) {
    return '${prefix}the move gives check. The opponent must respond, which can give your pieces time to improve or create tactical threats.';
  }
  if (san.contains('x')) {
    return '${prefix}the move captures material. Compare the recapture sequence before assuming that the exchange wins material.';
  }

  final match = RegExp(r'([a-h][1-8])(?:=[QRBN])?[+#]?$').firstMatch(san);
  final square = match?.group(1);
  if (square == null) {
    return 'Lichess prefers this move at the current search depth. A position-specific explanation requires comparing engine continuations.';
  }

  if (san.startsWith('N')) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    final attacks = <String>[];
    for (final offset in const <(int, int)>[
      (1, 2), (2, 1), (2, -1), (1, -2),
      (-1, -2), (-2, -1), (-2, 1), (-1, 2),
    ]) {
      final f = file + offset.$1;
      final r = rank + offset.$2;
      if (f >= 0 && f < 8 && r >= 0 && r < 8) {
        attacks.add('${String.fromCharCode('a'.codeUnitAt(0) + f)}${r + 1}');
      }
    }
    final centralAttacks = attacks.where(
      (s) => const {'d4', 'e4', 'd5', 'e5'}.contains(s),
    ).toList();
    if (centralAttacks.isNotEmpty) {
      return '${prefix}the knight on $square attacks ${centralAttacks.join(' and ')}, important central squares. Check whether that pressure helps your position more than the played move.';
    }
    return '${prefix}the knight on $square gains access to new squares. Its tactical value depends on what it attacks or defends in this position.';
  }
  if (san.startsWith('B')) {
    return '${prefix}the bishop moves to $square, changing the diagonals it influences. Check whether it pressures an enemy piece or supports your center.';
  }
  if (san.startsWith('R')) {
    return '${prefix}the rook on $square changes which file and rank it influences. Check whether that line is open or can be opened.';
  }
  if (san.startsWith('Q')) {
    return '${prefix}the queen moves to $square, potentially creating threats. Check its safety and whether it coordinates with another piece.';
  }
  if (san.startsWith('K')) {
    return '${prefix}the king moves to $square. Check whether this avoids a threat or improves the king in the endgame.';
  }
  if (const {'d4', 'e4', 'd5', 'e5'}.contains(square)) {
    return '${prefix}the pawn on $square occupies the center and attacks nearby squares. Check how the opponent could challenge it.';
  }
  return '${prefix}the pawn moves to $square. Check what lines it opens and which squares it protects or weakens.';
}
