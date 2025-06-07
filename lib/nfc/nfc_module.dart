import 'nfc_module_platform_interface.dart';
import 'nfc_result.dart';

class NfcModule {
  Future<String?> getPlatformVersion() {
    return NfcModulePlatform.instance.getPlatformVersion();
  }

  void initializeNfc() {
    NfcModulePlatform.instance.initializeNfc();
  }

  Stream<NfcEvent>? get onNfcEvent => NfcModulePlatform.instance.onNfcEvent();

  Future<String> prepareReadBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
  }) {
    return NfcModulePlatform.instance.prepareReadBlock(
      sectorIndex: sectorIndex,
      blockIndex: blockIndex,
      keyHex: keyHex,
    );
  }

  Future<String> prepareWriteBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
    required String dataHex,
  }) {
    return NfcModulePlatform.instance.prepareWriteBlock(
      sectorIndex: sectorIndex,
      blockIndex: blockIndex,
      keyHex: keyHex,
      dataHex: dataHex,
    );
  }

  Future<String> prepareResetCard({required String keyHex}) {
    return NfcModulePlatform.instance.prepareResetCard(keyHex: keyHex);
  }

  Future<String> prepareReadMultipleBlocks({
    required List<NfcReadTarget> targets,
    required String keyHex,
  }) {
    return NfcModulePlatform.instance.prepareReadMultipleBlocks(
      targets: targets,
      keyHex: keyHex,
    );
  }

  Future<String> prepareWriteMultipleBlocks({
    required List<NfcWriteTarget> targets,
    required String keyHex,
  }) {
    return NfcModulePlatform.instance.prepareWriteMultipleBlocks(
      targets: targets,
      keyHex: keyHex,
    );
  }

  Future<void> cancelOperation() {
    return NfcModulePlatform.instance.cancelOperation();
  }

  void dispose() {
    NfcModulePlatform.instance.dispose();
  }
}
