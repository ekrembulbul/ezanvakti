import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/alarms/domain/math_challenge.dart';

const Key kMathSubmitKey = Key('math_submit');

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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_index + 1} / ${_questions.length}',
          style: AppTypography.tabLabel.copyWith(color: tokens.textTertiary),
        ),
        const SizedBox(height: 16),
        Text(
          question.text,
          style: AppTypography.counter.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(hintText: 'Cevap'),
        ),
        if (_wrong) ...[
          const SizedBox(height: 8),
          Text(
            'Yanlış, tekrar dene.',
            style: AppTypography.tabLabel.copyWith(color: tokens.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: kMathSubmitKey,
          onPressed: _submit,
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}
