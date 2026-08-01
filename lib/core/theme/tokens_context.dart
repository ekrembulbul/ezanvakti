import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Widget'ların renk token'larına kısa yoldan erişmesi için.
///
/// `Theme.of(context).extension<AppTokens>()!` yerine `context.tokens`.
extension TokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
