import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nfc_module_platform_interface.dart';
import 'nfc_result.dart';

/// An implementation of [NfcModulePlatform] that uses method channels.
class MethodChannelNfcModule extends NfcModulePlatform {
  String defaultKey = "FFFFFFFFFFFF";

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nfc_module');
  StreamController<NfcEvent>? _nfcStreamController;

  Future<void> _handleNfcMethodCall(MethodCall call) async {
    try {
      final Map<Object?, Object?> args =
          call.arguments as Map<Object?, Object?>;
      switch (call.method) {
        case 'onReadResult':
          _nfcStreamController?.add(
            NfcReadSuccess(
              sector: args['sector'] as int,
              block: args['block'] as int,
              dataHex: args['dataHex'] as String,
            ),
          );
          break;
        case 'onWriteResult':
          _nfcStreamController?.add(
            NfcWriteSuccess(
              sector: args['sector'] as int,
              block: args['block'] as int,
            ),
          );
          break;
        case 'onResetResult':
          _nfcStreamController?.add(
            NfcResetSuccess(sectorsReset: args['sectorsReset'] as int),
          );
          break;
        case 'onMultiReadResult':
          final rawResults = args['results'] as List<Object?>;
          final results = rawResults
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _nfcStreamController?.add(NfcMultiBlockReadSuccess(results: results));
          break;
        case 'onMultiWriteResult':
          final rawResults = args['results'] as List<Object?>;
          final results = rawResults
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _nfcStreamController?.add(
            NfcMultiBlockWriteSuccess(results: results),
          );
          break;
        case 'onError':
          _nfcStreamController?.add(
            NfcError(
              errorCode: args['errorCode'] as String,
              errorMessage: args['errorMessage'] as String,
            ),
          );
          break;
      }
    } catch (e) {
      _nfcStreamController?.addError(e);
    }
  }

  @override
  Stream<NfcEvent>? onNfcEvent() => _nfcStreamController?.stream;

  @override
  Future<String> prepareReadBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
  }) async {
    return await methodChannel.invokeMethod('prepareReadBlock', {
      'sectorIndex': sectorIndex,
      'blockIndex': blockIndex,
      'keyHex': keyHex,
    });
  }

  @override
  Future<String> prepareWriteBlock({
    required int sectorIndex,
    required int blockIndex,
    required String keyHex,
    required String dataHex,
  }) async {
    if (dataHex.length != 32) {
      throw ArgumentError(
        'Data hex harus memiliki panjang 32 karakter (16 byte).',
      );
    }
    return await methodChannel.invokeMethod('prepareWriteBlock', {
      'sectorIndex': sectorIndex,
      'blockIndex': blockIndex,
      'keyHex': keyHex,
      'dataHex': dataHex,
    });
  }

  @override
  Future<String> prepareResetCard({required String keyHex}) async {
    return await methodChannel.invokeMethod('prepareResetCard', {
      'keyHex': keyHex,
    });
  }

  @override
  Future<String> prepareReadMultipleBlocks({
    required List<NfcReadTarget> targets,
    required String keyHex,
  }) async {
    final targetMaps = targets.map((t) => t.toMap()).toList();
    return await methodChannel.invokeMethod('prepareReadMultipleBlocks', {
      'targets': targetMaps,
      'keyHex': keyHex,
    });
  }

  @override
  Future<void> cancelOperation() async {
    await methodChannel.invokeMethod('cancelOperation');
  }

  @override
  void dispose() {
    methodChannel.setMethodCallHandler(null);
    _nfcStreamController?.close();
    _nfcStreamController = null;
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  void initializeNfc() {
    _nfcStreamController ??= StreamController<NfcEvent>.broadcast();
    methodChannel.setMethodCallHandler(_handleNfcMethodCall);
  }

  @override
  Future<String> prepareWriteMultipleBlocks({
    required List<NfcWriteTarget> targets,
    required String keyHex,
  }) async {
    final targetMaps = targets.map((t) => t.toMap()).toList();
    for (var target in targets) {
      if (target.dataHex.length != 32) {
        throw ArgumentError(
          'Setiap data hex harus memiliki panjang 32 karakter (16 byte).',
        );
      }
    }
    return await methodChannel.invokeMethod('prepareWriteMultipleBlocks', {
      'targets': targetMaps,
      'keyHex': keyHex,
    });
  }
}
