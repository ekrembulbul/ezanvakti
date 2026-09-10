import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/alarms/domain/math_challenge.dart';
import '../../../l10n/l10n_extensions.dart';
import 'mission_metrics.dart';

const Key kMathSubmitKey = Key('math_submit');
const Key kMathProgressKey = Key('math_progress');
const Key kMathAnswerKey = Key('math_answer');
const Key kMathBackspaceKey = Key('math_backspace');

/// Tuş takımındaki rakam tuşu (0–9).
Key kMathKey(int digit) => Key('math_key_$digit');

const Duration _kAnimation = Duration(milliseconds: 220);

/// Cevap alanının aldığı en çok hane; en büyük cevap 99 × 99 = 9801.
const int _kMaxDigits = 6;
const double _kKeyGap = 10;

/// Matematik görevi: sorular sırayla sorulur, hepsi doğru cevaplanınca
/// [onCompleted] çağrılır. Yanlış cevap ilerletmez.
///
/// Cevap sistem klavyesiyle değil ekrandaki tuş takımıyla girilir: klavye
/// açılınca alan daralıp gövde kaydırılır oluyordu; uyku sersemi biri küçük
/// bir alanda kaydırma yapmamalı. Tuş takımı kalan alanın tamamını doldurur.
class MathMission extends StatefulWidget {
  final int level;
  final Random random;
  final VoidCallback onCompleted;

  const MathMission({
    super.key,
    required this.level,
    required this.random,
    required this.onCompleted,
  });

  @override
  State<MathMission> createState() => _MathMissionState();
}

class _MathMissionState extends State<MathMission> {
  late final List<MathQuestion> _questions;
  String _input = '';
  int _index = 0;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _questions = MathChallenge.generate(
      level: widget.level,
      random: widget.random,
    );
  }

  bool get _isLast => _index + 1 >= _questions.length;

  void _append(int digit) {
    if (_input.length >= _kMaxDigits) return;
    setState(() {
      _input += '$digit';
      _wrong = false;
    });
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _wrong = false;
    });
  }

  void _clear() {
    if (_input.isEmpty) return;
    setState(() {
      _input = '';
      _wrong = false;
    });
  }

  void _submit() {
    final typed = int.tryParse(_input);
    if (typed == null) return;
    if (typed != _questions[_index].answer) {
      // Yanlis girdi temizlenir: kullanici silmekle ugrasmadan yeniden yazar.
      setState(() {
        _wrong = true;
        _input = '';
      });
      return;
    }
    if (_isLast) {
      widget.onCompleted();
      return;
    }
    setState(() {
      _index++;
      _input = '';
      _wrong = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final question = _questions[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progress(tokens),
        const SizedBox(height: 14),
        _questionCard(tokens, question),
        const SizedBox(height: 14),
        _answerDisplay(tokens),
        const SizedBox(height: 6),
        _wrongHint(tokens),
        const SizedBox(height: 8),
        Expanded(child: _keypad(tokens)),
      ],
    );
  }

  /// Kaçıncı soruda olduğunu noktalarla gösterir; sayı okumaktan hızlı.
  Widget _progress(AppTokens tokens) {
    if (_questions.length < 2) return const SizedBox.shrink();
    return Row(
      key: kMathProgressKey,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _questions.length; i++)
          AnimatedContainer(
            duration: _kAnimation,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _index ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i <= _index ? tokens.accent : tokens.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  /// Soru, ekranın en büyük ve tek odak noktası.
  Widget _questionCard(AppTokens tokens, MathQuestion question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.divider),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          question.text,
          style: AppTypography.counter.copyWith(color: tokens.textPrimary),
        ),
      ),
    );
  }

  /// Tuşlarla girilen cevap. Boşken ipucu, yanlışta vurgulu çerçeve.
  Widget _answerDisplay(AppTokens tokens) {
    final empty = _input.isEmpty;
    return AnimatedContainer(
      key: kMathAnswerKey,
      duration: _kAnimation,
      curve: Curves.easeOutCubic,
      height: kMissionButtonHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _wrong ? tokens.accent : tokens.divider,
          width: _wrong ? 1.5 : 1,
        ),
      ),
      child: Text(
        empty ? context.l10n.missionAnswerHint : _input,
        style: AppTypography.counter.copyWith(
          fontSize: 30,
          color: empty ? tokens.textTertiary : tokens.textPrimary,
        ),
      ),
    );
  }

  Widget _wrongHint(AppTokens tokens) {
    return AnimatedOpacity(
      duration: _kAnimation,
      opacity: _wrong ? 1 : 0,
      child: Text(
        context.l10n.missionWrongAnswer,
        textAlign: TextAlign.center,
        style: AppTypography.rowSubtitle.copyWith(
          fontSize: kMissionSupportFontSize,
          color: tokens.textSecondary,
        ),
      ),
    );
  }

  /// 3×4 tuş takımı: satırlar ve tuşlar `Expanded` olduğu için kalan alanı
  /// paylaşır; hiçbir ekran yüksekliğinde taşmaz, büyük ekranda büyür.
  Widget _keypad(AppTokens tokens) {
    final rows = <List<Widget>>[
      [_digitKey(tokens, 1), _digitKey(tokens, 2), _digitKey(tokens, 3)],
      [_digitKey(tokens, 4), _digitKey(tokens, 5), _digitKey(tokens, 6)],
      [_digitKey(tokens, 7), _digitKey(tokens, 8), _digitKey(tokens, 9)],
      [_backspaceKey(tokens), _digitKey(tokens, 0), _submitKey(tokens)],
    ];
    return Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: _kKeyGap),
          Expanded(
            child: Row(
              children: [
                for (final (j, key) in row.indexed) ...[
                  if (j > 0) const SizedBox(width: _kKeyGap),
                  Expanded(child: key),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _digitKey(AppTokens tokens, int digit) {
    return _key(
      tokens,
      key: kMathKey(digit),
      semanticLabel: '$digit',
      onTap: () => _append(digit),
      child: Text(
        '$digit',
        style: AppTypography.gridValue.copyWith(
          fontSize: kMissionKeyFontSize,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
    );
  }

  Widget _backspaceKey(AppTokens tokens) {
    return _key(
      tokens,
      key: kMathBackspaceKey,
      semanticLabel: context.l10n.actionDelete,
      onTap: _backspace,
      onLongPress: _clear,
      child: Icon(
        Icons.backspace_outlined,
        size: kMissionKeyFontSize,
        color: tokens.textSecondary,
      ),
    );
  }

  Widget _submitKey(AppTokens tokens) {
    final label = _isLast
        ? context.l10n.missionFinish
        : context.l10n.missionConfirm;
    return _key(
      tokens,
      key: kMathSubmitKey,
      semanticLabel: label,
      onTap: _submit,
      fill: tokens.accent,
      border: tokens.accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 28, color: Colors.white),
          Text(
            label,
            style: AppTypography.rowSubtitle.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(
    AppTokens tokens, {
    required Key key,
    required String semanticLabel,
    required VoidCallback onTap,
    required Widget child,
    VoidCallback? onLongPress,
    Color? fill,
    Color? border,
  }) {
    final radius = BorderRadius.circular(kMissionButtonRadius);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        key: key,
        color: fill ?? tokens.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: border ?? tokens.divider),
            ),
            // Cok kisa ekranda icerik tusa sigmazsa tasmak yerine kuculsun.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ExcludeSemantics(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
