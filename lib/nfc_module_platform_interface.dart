import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nfc_module_method_channel.dart';
import 'nfc_result.dart';

abstract class NfcModulePlatform extends PlatformInterface {
  /// Constructs a NfcModulePlatform.
  NfcModulePlatform() : super(token: _token);

  static final Object _token = Object();

  static NfcModulePlatform _instance = MethodChannelNfcModule();

  /// The default instance of [NfcModulePlatform] to use.
  ///
  /// Defaults to [MethodChannelNfcModule].
  static NfcModulePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NfcModulePlatform] when
  /// they register themselves.
  static set instance(NfcModulePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  void initializeNfc() {
    throw UnimplementedError('initializeNfc() has not been implemented.');
  }

  Stream<NfcEvent>? onNfcEvent() {
    throw UnimplementedError('onNfcEvent() has not been implemented.');
  }

  Future<String> prepareReadBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
  }) {
    throw UnimplementedError('prepareReadSector() has not been implemented.');
  }

  Future<String> prepareWriteBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
    required String dataHex,
  }) {
    throw UnimplementedError('prepareWriteSector() has not been implemented.');
  }

  Future<String> prepareResetCard({required String keyHex}) {
    throw UnimplementedError('prepareResetSector() has not been implemented.');
  }

  Future<void> cancelOperation() {
    throw UnimplementedError('cancelOperation() has not been implemented.');
  }

  void dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
