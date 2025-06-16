import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nfc_module_platform_interface.dart';
import 'nfc_result.dart';
import 'nfc_status.dart';

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
        case 'onReadProgressUpdate':
          _nfcStreamController?.add(
            NfcProgressUpdate(
              completed: args['completed'] as int,
              total: args['total'] as int,
              operation: 'Membaca',
            ),
          );
          break;
        case 'onWriteProgressUpdate':
          _nfcStreamController?.add(
            NfcProgressUpdate(
              completed: args['completed'] as int,
              total: args['total'] as int,
              operation: 'Menulis',
            ),
          );
          break;
        case 'onResetProgressUpdate':
          _nfcStreamController?.add(
            NfcProgressUpdate(
              completed: args['completed'] as int,
              total: args['total'] as int,
              operation: 'Mereset',
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
  Future<String> prepareResetCard({required Uint8List keyBytes}) async {
    return await methodChannel.invokeMethod('prepareResetCard', {
      'keyBytes': keyBytes,
    });
  }

  @override
  Future<String> prepareReadMultipleBlocks({
    required List<NfcReadTarget> targets,
    required Uint8List keyBytes,
  }) async {
    final targetMaps = targets.map((t) => t.toMap()).toList();
    return await methodChannel.invokeMethod('prepareReadMultipleBlocks', {
      'targets': targetMaps,
      'keyBytes': keyBytes,
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
    required Uint8List keyBytes,
  }) async {
    final targetMaps = targets.map((t) => t.toMap()).toList();
    for (var target in targets) {
      if (target.dataBytes.length != 16) {
        throw ArgumentError('Data harus 16 byte.');
      }
    }
    return await methodChannel.invokeMethod('prepareWriteMultipleBlocks', {
      'targets': targetMaps,
      'keyBytes': keyBytes,
    });
  }

  @override
  Future<NfcStatus> checkNfcStatus() async {
    try {
      final String? status = await methodChannel.invokeMethod('checkNfcStatus');

      switch (status) {
        case 'enabled':
          return NfcStatus.enabled;
        case 'disabled':
          return NfcStatus.disabled;
        default:
          return NfcStatus.notSupported;
      }
    } on PlatformException catch (e) {
      return NfcStatus.notSupported;
    }
  }
}
