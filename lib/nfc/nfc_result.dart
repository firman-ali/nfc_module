import 'package:flutter/material.dart';

@immutable
sealed class NfcEvent {
  const NfcEvent();
}

class NfcReadSuccess extends NfcEvent {
  const NfcReadSuccess({
    required this.sector,
    required this.block,
    required this.dataHex,
  });
  final int sector;
  final int block;
  final String dataHex;
}

class NfcWriteSuccess extends NfcEvent {
  const NfcWriteSuccess({required this.sector, required this.block});
  final int sector;
  final int block;
}

class NfcResetSuccess extends NfcEvent {
  const NfcResetSuccess({required this.sectorsReset});
  final int sectorsReset;
}

class NfcError extends NfcEvent {
  const NfcError({required this.errorCode, required this.errorMessage});
  final String errorCode;
  final String errorMessage;
}

class NfcMultiBlockReadSuccess extends NfcEvent {
  const NfcMultiBlockReadSuccess({required this.results});
  final List<Map<String, dynamic>> results;
}

class NfcMultiBlockWriteSuccess extends NfcEvent {
  const NfcMultiBlockWriteSuccess({required this.results});
  final List<Map<String, dynamic>> results;
}
