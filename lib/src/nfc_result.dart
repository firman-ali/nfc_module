import 'package:flutter/material.dart';

@immutable
sealed class NfcEvent {
  const NfcEvent();
}

class NfcMultiBlockReadSuccess extends NfcEvent {
  const NfcMultiBlockReadSuccess({required this.results});
  final List<Map<String, dynamic>> results;
}

class NfcMultiBlockWriteSuccess extends NfcEvent {
  const NfcMultiBlockWriteSuccess({required this.results});
  final List<Map<String, dynamic>> results;
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

class NfcProgressUpdate extends NfcEvent {
  const NfcProgressUpdate({
    required this.completed,
    required this.total,
    required this.operation,
  });
  final int completed;
  final int total;
  final String operation;
}
