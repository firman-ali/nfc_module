import 'package:flutter/material.dart';

@immutable
class NfcScanResult {
  const NfcScanResult({
    required this.data,
    required this.successCount,
    required this.scanTime,
  });

  final String data;
  final int successCount;
  final int scanTime;
}
