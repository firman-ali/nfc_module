import 'dart:typed_data';

import 'package:nfc_module/nfc_module.dart';

class NfcModule {
  Future<String?> getPlatformVersion() {
    return NfcModulePlatform.instance.getPlatformVersion();
  }

  void initializeNfc() {
    NfcModulePlatform.instance.initializeNfc();
  }

  Stream<NfcEvent>? get onNfcEvent => NfcModulePlatform.instance.onNfcEvent();

  Future<String> prepareResetCard({required Uint8List keyBytes}) {
    return NfcModulePlatform.instance.prepareResetCard(keyBytes: keyBytes);
  }

  Future<String> prepareReadMultipleBlocks({
    required List<NfcReadTarget> targets,
    required Uint8List keyBytes,
  }) {
    return NfcModulePlatform.instance.prepareReadMultipleBlocks(
      targets: targets,
      keyBytes: keyBytes,
    );
  }

  Future<String> prepareWriteMultipleBlocks({
    required List<NfcWriteTarget> targets,
    required Uint8List keyBytes,
  }) {
    return NfcModulePlatform.instance.prepareWriteMultipleBlocks(
      targets: targets,
      keyBytes: keyBytes,
    );
  }

  Future<void> cancelOperation() {
    return NfcModulePlatform.instance.cancelOperation();
  }

  void dispose() {
    NfcModulePlatform.instance.dispose();
  }

  Future<NfcStatus> checkNfcStatus() async {
    final status = await NfcModulePlatform.instance.checkNfcStatus();
    return status;
  }
}
