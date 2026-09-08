import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _SilentDefaultFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => false;
}

class _RecordingOutput extends LogOutput {
  final messages = <String>[];
  @override
  void output(OutputEvent event) => messages.addAll(event.lines);
}

void main() {
  test('Application errors survive a silent library default filter', () {
    final previousFilter = Logger.defaultFilter;
    final previousOutput = Logger.defaultOutput;
    final output = _RecordingOutput();
    Logger.defaultFilter = () => _SilentDefaultFilter();
    Logger.defaultOutput = () => output;
    addTearDown(() {
      Logger.defaultFilter = previousFilter;
      Logger.defaultOutput = previousOutput;
    });

    AppLogger().error('alarm-diagnostic-error');
    AppLogger().warning('alarm-diagnostic-warning');

    expect(
      output.messages.any((line) => line.contains('alarm-diagnostic-error')),
      isTrue,
    );
    expect(
      output.messages.any((line) => line.contains('alarm-diagnostic-warning')),
      isTrue,
    );
  });
}
