import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_module/nfc_module.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNfcModulePlatform
    with MockPlatformInterfaceMixin
    implements NfcModulePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  void initializeNfc() {
    return;
  }

  @override
  Future<String> prepareReadBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelOperation() {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    return;
  }

  @override
  Stream<NfcEvent> onNfcEvent() {
    throw UnimplementedError();
  }

  @override
  Future<String> prepareWriteBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
    required String dataHex,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> prepareResetCard({required String keyHex}) {
    throw UnimplementedError();
  }

  @override
  Future<String> prepareReadMultipleBlocks({
    required List<NfcReadTarget> targets,
    required String keyHex,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> prepareWriteMultipleBlocks({
    required List<NfcWriteTarget> targets,
    required String keyHex,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  final NfcModulePlatform initialPlatform = NfcModulePlatform.instance;

  test('$MethodChannelNfcModule is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNfcModule>());
  });

  test('getPlatformVersion', () async {
    NfcModule nfcModulePlugin = NfcModule();
    MockNfcModulePlatform fakePlatform = MockNfcModulePlatform();
    NfcModulePlatform.instance = fakePlatform;

    expect(await nfcModulePlugin.getPlatformVersion(), '42');
  });
}
