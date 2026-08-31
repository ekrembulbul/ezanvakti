import 'dart:math';
import '../../../l10n/l10n_extensions.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import 'mission_metrics.dart';
import '../../../features/alarms/domain/math_challenge.dart';

const Key kMathSubmitKey = Key('math_submit');
const Key kMathFieldKey = Key('math_field');
const Key kMathProgressKey = Key('math_progress');
const Duration _kAnimation = Duration(milliseconds: 220);

/// Matematik görevi: sorular sırayla sorulur, hepsi doğru cevaplanınca
/// [onCompleted] çağrılır. Yanlış cevap ilerletmez.
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
  final _controller = TextEditingController();
  int _index = 0;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _questions = MathChallenge.generate(
      level: widget.level,
      random: widget.random,
    );
    _controller.addListener(() {
      if (_wrong) setState(() => _wrong = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = int.tryParse(_controller.text.trim());
    if (typed == null || typed != _questions[_index].answer) {
      setState(() => _wrong = true);
      return;
    }
    _controller.clear();
    if (_index + 1 >= _questions.length) {
      widget.onCompleted();
      return;
    }
    setState(() {
      _index++;
      _wrong = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final question = _questions[_index];

    // Klavye acilinca alan daraliyor; icerik sabit yuksekliklere sahip
    // oldugu icin kaydirilabilir olmali, yoksa tasiyor.
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _progress(tokens),
          const SizedBox(height: 24),
          _questionCard(tokens, question),
          const SizedBox(height: 20),
          _answerField(tokens),
          SizedBox(height: _wrong ? 10 : 0),
          _wrongHint(tokens),
          const SizedBox(height: 24),
          _submitButton(tokens),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.divider),
      ),
      child: FittedBox(
        child: Text(
          question.text,
          style: AppTypography.counter.copyWith(color: tokens.textPrimary),
        ),
      ),
    );
  }

  Widget _answerField(AppTokens tokens) {
    final borderColor = _wrong ? tokens.accent : tokens.divider;

    return AnimatedContainer(
      duration: _kAnimation,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: _wrong ? 1.5 : 1),
      ),
      child: TextField(
        key: kMathFieldKey,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        onSubmitted: (_) => _submit(),
        style: AppTypography.gridValue.copyWith(color: tokens.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 22),
          hintText: context.l10n.missionAnswerHint,
          hintStyle: AppTypography.gridValue.copyWith(
            color: tokens.textTertiary,
          ),
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
        style: AppTypography.rowSubtitle.copyWith(
          fontSize: kMissionSupportFontSize,
          color: tokens.textSecondary,
        ),
      ),
    );
  }

  Widget _submitButton(AppTokens tokens) {
    return SizedBox(
      width: double.infinity,
      height: kMissionButtonHeight,
      child: FilledButton(
        key: kMathSubmitKey,
        onPressed: _submit,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        child: Text(
          _index + 1 >= _questions.length
              ? context.l10n.missionFinish
              : context.l10n.missionConfirm,
          style: AppTypography.rowTitle.copyWith(
            color: Colors.white,
            fontSize: kMissionButtonFontSize,
          ),
        ),
      ),
    );
  }
}
