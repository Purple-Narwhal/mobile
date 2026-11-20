import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/engine/practice_comment.dart';

/// Evidence-first coaching for offline Practice. Never infers engine preference
/// from the SAN text or uses a network/language-model service.
class PracticeCoachReport {
  const PracticeCoachReport({
    required this.heading,
    required this.explanation,
    required this.question,
    required this.confidence,
    required this.bestLine,
    required this.playedLine,
    required this.depth,
  });

  final String heading;
  final String explanation;
  final String question;
  /// 'Line verified', 'Position verified', or 'Limited evidence'.
  final String confidence;
  final List<String> bestLine;
  final List<String> playedLine;
  final int? depth;
}

/// An intentionally small fact, not prose. Candidate facts are ranked so a
/// forcing tactic wins over generic positional observations.
class _Finding {
  const _Finding(this.priority, this.heading, this.explanation, this.question, this.confidence);
  final int priority;
  final String heading;
  final String explanation;
  final String question;
  final String confidence;
}

class _Line {
  const _Line(this.san, this.positions);
  final List<String> san;
  final List<Position> positions;
  static const empty = _Line([], []);

  static _Line replay(Position before, Iterable<String> uci, {int limit = 8}) {
    final san = <String>[];
    final positions = <Position>[];
    var position = before;
    for (final token in uci.take(limit)) {
      final move = Move.parse(token);
      if (move == null || !position.isLegal(move)) break;
      final result = position.makeSanUnchecked(move);
      position = result.$1;
      san.add(result.$2);
      positions.add(position);
    }
    return _Line(san, positions);
  }

  String get display => san.take(6).join('  ');
}

bool _sameMove(String a, String b) => a == b || normalizeUci(a) == normalizeUci(b);

List<String> _matchingPv(ClientEval? evaluation, String uci) {
  if (evaluation == null) return [];
  for (final pv in evaluation.pvs) {
    if (pv.moves.isNotEmpty && _sameMove(pv.moves.first, uci)) {
      return pv.moves.toList();
    }
  }
  return [];
}

List<String> _firstPv(ClientEval? evaluation) =>
    evaluation != null && evaluation.pvs.isNotEmpty
        ? evaluation.pvs.first.moves.toList()
        : [];

/// Parse piece placement without assuming that a move was tactical.
/// This deliberately works for standard-like variants; only material facts
/// that are true in the supplied positions are described.
class _Pieces {
  _Pieces(String fen) {
    final ranks = fen.split(' ').first.split('/');
    if (ranks.length != 8) return;
    for (var rank = 0; rank < 8; rank++) {
      var file = 0;
      for (final ch in ranks[rank].split('')) {
        final digit = int.tryParse(ch);
        if (digit != null) {
          file += digit;
        } else {
          if (file < 8) _board[rank * 8 + file] = ch;
          file++;
        }
      }
    }
  }

  final List<String> _board = List.filled(64, '.');

  String at(int square) => square >= 0 && square < 64 ? _board[square] : '.';
  static bool isWhite(String p) => p != '.' && p == p.toUpperCase();
  static String square(int i) => '${String.fromCharCode(97 + (i % 8))}${8 - i ~/ 8}';
  static int squareIndex(String s) {
    if (s.length != 2) return -1;
    final file = s.codeUnitAt(0) - 97, rank = s.codeUnitAt(1) - 49;
    return file >= 0 && file < 8 && rank >= 0 && rank < 8 ? (7 - rank) * 8 + file : -1;
  }

  static int worth(String p) => switch (p.toLowerCase()) {
    'p' => 100,
    'n' => 320,
    'b' => 330,
    'r' => 500,
    'q' => 900,
    _ => 0,
  };

  int materialLead(bool white) {
    var lead = 0;
    for (final piece in _board) {
      if (piece == '.') continue;
      lead += (isWhite(piece) == white ? 1 : -1) * worth(piece);
    }
    return lead;
  }

  Set<int> attackedByPiece(int from) {
    final piece = at(from);
    if (piece == '.') return {};
    final file = from % 8, rank = from ~/ 8;
    final role = piece.toLowerCase();
    final attacks = <int>{};
    void add(int df, int dr, {bool ray = false}) {
      var f = file + df, r = rank + dr;
      while (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final target = r * 8 + f;
        attacks.add(target);
        if (!ray || at(target) != '.') break;
        f += df;
        r += dr;
      }
    }
    if (role == 'p') {
      final direction = isWhite(piece) ? -1 : 1;
      add(-1, direction);
      add(1, direction);
    } else if (role == 'n') {
      for (final offset in const <(int, int)>[
        (1, 2), (2, 1), (2, -1), (1, -2),
        (-1, -2), (-2, -1), (-2, 1), (-1, 2),
      ]) {
        add(offset.$1, offset.$2);
      }
    } else {
      if (role == 'k' || role == 'q' || role == 'b') {
        for (final offset in const <(int, int)>[(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
          add(offset.$1, offset.$2, ray: role != 'k');
        }
      }
      if (role == 'k' || role == 'q' || role == 'r') {
        for (final offset in const <(int, int)>[(1, 0), (0, 1), (-1, 0), (0, -1)]) {
          add(offset.$1, offset.$2, ray: role != 'k');
        }
      }
    }
    return attacks;
  }

  bool attacked(int target, {required bool byWhite}) {
    for (var i = 0; i < 64; i++) {
      if (at(i) != '.' && isWhite(at(i)) == byWhite && attackedByPiece(i).contains(target)) {
        return true;
      }
    }
    return false;
  }
}

String _pieceName(String piece) => switch (piece.toLowerCase()) {
  'p' => 'pawn',
  'n' => 'knight',
  'b' => 'bishop',
  'r' => 'rook',
  'q' => 'queen',
  'k' => 'king',
  _ => 'piece',
};

/// Generates the best supported explanation from verifiable board facts.
/// A missing or stale PV is never treated as proof of why a move was preferred.
PracticeCoachReport buildPracticeCoachReport({
  required Position before,
  required SanMove played,
  required MoveVerdict verdict,
  SanMove? suggested,
  ClientEval? beforeEval,
  ClientEval? afterEval,
}) {
  final validBeforeEval = beforeEval?.position.fen == before.fen ? beforeEval : null;
  final playedMove = played.move;
  final recommendedMove = suggested?.move;
  final recommendedUci = recommendedMove?.uci ?? playedMove.uci;
  final bestPv = _matchingPv(validBeforeEval, recommendedUci);
  final playedPv = _matchingPv(validBeforeEval, playedMove.uci);
  final best = _Line.replay(before, bestPv.isNotEmpty ? bestPv : [recommendedUci]);
  _Line actual;
  if (playedPv.isNotEmpty) {
    actual = _Line.replay(before, playedPv);
  } else {
    final next = before.isLegal(playedMove)
        ? before.makeSanUnchecked(playedMove).$1
        : null;
    final verifiedAfter = next != null && afterEval?.position.fen == next.fen
        ? afterEval
        : null;
    actual = _Line.replay(
      before,
      [playedMove.uci, ..._firstPv(verifiedAfter)],
    );
  }

  final isGood = verdict == MoveVerdict.goodMove;
  final white = before.turn == Side.white;
  final baseBoard = _Pieces(before.fen);
  final findings = <_Finding>[];

  if (best.san.isNotEmpty && best.san.first.endsWith('#')) {
    findings.add(_Finding(
      110,
      'A checkmate was available',
      '${best.san.first} ends the game immediately. That is a concrete reason to prefer it over ${played.san}.',
      'Before choosing a quieter move, can you find a forcing check that leaves the king no escape?',
      'Line verified',
    ));
  }

  if (actual.san.length > 1 && actual.san[1].endsWith('#')) {
    findings.add(_Finding(
      105,
      'Your move allows checkmate',
      'After ${actual.san.first}, the engine line replies ${actual.san[1]}#. The opponent has a direct finishing move.',
      'Which forcing check should you have noticed before playing ${played.san}?',
      'Line verified',
    ));
  }

  // A capture in the opponent's principal variation is stronger evidence
  // than a guessed hanging-piece label. Only call it a material problem when
  // the actual line loses significant material relative to the best line.
  if (!isGood &&
      actual.positions.length >= 2 &&
      best.positions.length >= 2 &&
      actual.san[1].contains('x')) {
    final actualLead = _Pieces(actual.positions.last.fen).materialLead(white);
    final bestLead = _Pieces(best.positions.last.fen).materialLead(white);
    final baseLead = baseBoard.materialLead(white);
    final loss = baseLead - actualLead;
    if (loss >= 200 && bestLead - actualLead >= 180) {
      final reply = actual.san[1];
      findings.add(_Finding(
        95,
        'The opponent has a costly capture',
        'After ${actual.san.first}, the engine continues with ${reply}. '
            'The analysed continuation leaves you about ${(loss / 100).toStringAsFixed(1)} '
            'pawn-equivalents worse in material than before the move. '
            'The line after ${best.san.first} retains more material.',
        'What can your opponent capture immediately after your move? Calculate the recaptures before committing.',
        'Line verified',
      ));
    }
  }

  if (actual.san.length >= 2 && actual.san[1].endsWith('+') && !isGood) {
    findings.add(_Finding(
      65,
      'The reply comes with check',
      'Following ${actual.san.first}, the engine chooses ${actual.san[1]}. '
          'A check forces your king to respond and can change the order of your plan.',
      'What forcing checks does your opponent gain if you play your move?',
      'Line verified',
    ));
  }

  if (best.san.isNotEmpty) {
    final recommendedSan = best.san.first;
    if (recommendedSan.endsWith('+') && !isGood) {
      findings.add(_Finding(
        57,
        'You passed up a forcing check',
        '${recommendedSan} gives check. The opponent must answer the king threat before pursuing their own plan.',
        'What changes when you make your opponent respond to a check first?',
        'Position verified',
      ));
    }

    if (recommendedSan.contains('x') && !isGood) {
      findings.add(_Finding(
        47,
        'A capture was available',
        '${recommendedSan} captures a piece or pawn. '
            'Whether the exchange is profitable depends on the continuation, not the capture alone.',
        'Calculate what can recapture after ${recommendedSan}. Does the exchange favor you?',
        'Position verified',
      ));
    }

    if (recommendedSan.startsWith('O-O')) {
      findings.add(_Finding(
        33,
        'A different king-safety plan',
        '${recommendedSan} castles, moving the king and rook together. '
            'It changes where your king can be attacked and how the rook can enter the game.',
        'Which of your king’s current lines of exposure would castling change?',
        'Position verified',
      ));
    }

    if (recommendedMove is NormalMove && best.positions.isNotEmpty &&
        !recommendedSan.startsWith('O-O')) {
      final from = _Pieces.squareIndex(recommendedMove.from.name);
      final to = _Pieces.squareIndex(recommendedMove.to.name);
      if (from >= 0 && to >= 0) {
        final piece = baseBoard.at(from);
        final bestBoard = _Pieces(best.positions.first.fen);
        final nowPiece = bestBoard.at(to);
        if (piece != '.' && nowPiece != '.' &&
            baseBoard.attacked(from, byWhite: !white) &&
            !bestBoard.attacked(to, byWhite: !white) &&
            playedMove.uci != recommendedMove.uci) {
          findings.add(_Finding(
            60,
            'The suggestion moves a piece out of danger',
            'Your ${_pieceName(piece)} on ${_Pieces.square(from)} is attacked. '
                '${recommendedSan} takes it to ${_Pieces.square(to)}, a square the opponent does not currently attack.',
            'Before moving elsewhere, identify which of your pieces can be taken.',
            'Position verified',
          ));
        }

        final targets = bestBoard.attackedByPiece(to)
            .where((s) {
              final p = bestBoard.at(s);
              return p != '.' && _Pieces.isWhite(p) != white && _Pieces.worth(p) >= 300;
            })
            .toList();
        if (nowPiece.toLowerCase() == 'n' && targets.length >= 2) {
          final names = targets.take(2).map((s) =>
              'the ${_pieceName(bestBoard.at(s))} on ${_Pieces.square(s)}').join(' and ');
          findings.add(_Finding(
            55,
            'A knight attacks two valuable pieces',
            'After ${recommendedSan}, your knight attacks $names at the same time. '
                'This is a double attack, though the engine line is needed to tell whether it wins material.',
            'Can both attacked pieces escape, or can the opponent answer with a forcing move?',
            'Position verified',
          ));
        }

        final center = <int>{_Pieces.squareIndex('d4'), _Pieces.squareIndex('e4'),
          _Pieces.squareIndex('d5'), _Pieces.squareIndex('e5')};
        final gained = bestBoard.attackedByPiece(to)
            .difference(baseBoard.attackedByPiece(from))
            .intersection(center).toList();
        if (gained.isNotEmpty && piece.toLowerCase() != 'k') {
          final squares = gained.map(_Pieces.square).join(' and ');
          findings.add(_Finding(
            20,
            'New pressure on the center',
            '${recommendedSan} brings your ${_pieceName(piece)} to ${_Pieces.square(to)}, '
                'adding influence over $squares that it did not exert from ${_Pieces.square(from)}.',
            'How can the opponent challenge those squares on their next turn?',
            'Position verified',
          ));
        }
      }
    }
  }

  // Chess advice must be driven by the evidence, never by an arbitrary
  // phrase variation. Sort by usefulness: mate > material > checks > pressure.
  findings.sort((a, b) => b.priority.compareTo(a.priority));
  final finding = findings.isNotEmpty
      ? findings.first
      : isGood
          ? const _Finding(
              1,
              'Your move holds up',
              'The practice evaluation considers this a good move. '
                  'There may be several sound continuations, not one uniquely correct idea.',
              'What reply would you choose if you were playing the other side?',
              'Limited evidence',
            )
          : _Finding(
              1,
              'The engine prefers a different continuation',
              'The practice evaluation prefers ${suggested?.san ?? 'another move'} over '
                  '${played.san}, but the available analysis does not establish one '
                  'specific tactical reason. A confident explanation would require a deeper line.',
              'Compare the opponent’s most forcing replies after each candidate move. What changes?',
              'Limited evidence',
            );

  return PracticeCoachReport(
    heading: finding.heading,
    explanation: finding.explanation,
    question: finding.question,
    confidence: finding.confidence,
    bestLine: best.san,
    playedLine: actual.san,
    depth: validBeforeEval?.depth,
  );
}
