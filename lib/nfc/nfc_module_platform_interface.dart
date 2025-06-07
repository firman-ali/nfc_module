import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nfc_module_method_channel.dart';
import 'nfc_result.dart';

class NfcReadTarget {
  const NfcReadTarget({required this.sectorIndex, required this.blockIndex});
  final int sectorIndex;
  final int blockIndex;

  Map<String, int> toMap() => {
    'sectorIndex': sectorIndex,
    'blockIndex': blockIndex,
  };
}

class NfcWriteTarget {
  const NfcWriteTarget({
    required this.sectorIndex,
    required this.blockIndex,
    required this.dataBytes,
  });
  final int sectorIndex;
  final int blockIndex;
  final Uint8List dataBytes;

  Map<String, dynamic> toMap() => {
    'sectorIndex': sectorIndex,
    'blockIndex': blockIndex,
    'dataBytes': dataBytes,
  };
}

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

  Future<String> prepareResetCard({required Uint8List keyBytes}) {
    throw UnimplementedError('prepareResetSector() has not been implemented.');
  }

  Future<void> cancelOperation() {
    throw UnimplementedError('cancelOperation() has not been implemented.');
  }

  void dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Future<String> prepareReadMultipleBlocks({
    required List<NfcReadTarget> targets,
    required Uint8List keyBytes,
  }) {
    throw UnimplementedError(
      'prepareReadMultipleBlocks() has not been implemented.',
    );
  }

  Future<String> prepareWriteMultipleBlocks({
    required List<NfcWriteTarget> targets,
    required Uint8List keyBytes,
  }) {
    throw UnimplementedError(
      'prepareWriteMultipleBlocks() has not been implemented.',
    );
  }
}
