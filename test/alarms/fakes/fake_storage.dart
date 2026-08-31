import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/abort_state.dart';
import 'package:ezanvakti/core/models/mission_session.dart';

/// Yalnizca gorev oturumu ve acil cikis kademesini tutan [LocalStorage].
///
/// Kalan method'lar bu testlerde cagrilmiyor; cagrilirsa test kirilsin diye
/// [noSuchMethod] uzerinden [UnimplementedError] firlatiyorlar.
class FakeStorage implements LocalStorage {

  List<QuietWindow> _quietWindows = [];

  @override
  Future<List<QuietWindow>> getQuietWindows() async => _quietWindows;

  @override
  Future<void> saveQuietWindows(List<QuietWindow> windows) async =>
      _quietWindows = windows;
  MissionSession? _session;
  AbortState _abort = const AbortState();

  @override
  Future<MissionSession?> getMissionSession() async => _session;

  @override
  Future<void> saveMissionSession(MissionSession? session) async {
    _session = session;
  }

  @override
  Future<AbortState> getAbortState() async => _abort;

  @override
  Future<void> saveAbortState(AbortState state) async {
    _abort = state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeStorage.${invocation.memberName}');
}
