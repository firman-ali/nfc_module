import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_module/nfc_module.dart';
import 'package:nfc_module/nfc_result.dart';

class NfcResetScreen extends StatefulWidget {
  const NfcResetScreen({super.key});

  @override
  State<NfcResetScreen> createState() => _NfcResetScreenState();
}

class _NfcResetScreenState extends State<NfcResetScreen> {
  final NfcModule _nfcModule = NfcModule();
  StreamSubscription<NfcEvent>? _nfcSubscription;

  String _status = 'Selamat datang!';
  String _result = '-';
  final String _defaultKey = "FFFFFFFFFFFF";

  void _prepareReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Reset Kartu'),
        content: const Text(
          'Tindakan ini akan menghapus SEMUA data di kartu dan tidak dapat diurungkan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final message = await _nfcModule.prepareResetCard(keyHex: _defaultKey);
        setState(() => _status = message);
      } catch (e) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nfcModule.initializeNfc();
    _nfcSubscription = _nfcModule.onNfcEvent?.listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event) {
          case NfcReadSuccess():
            _status =
                'Sukses Membaca Sektor ${event.sector}, Blok ${event.block}';
            _result = 'Data (Hex): ${event.dataHex}';
            break;
          case NfcWriteSuccess():
            _status =
                'Sukses Menulis ke Sektor ${event.sector}, Blok ${event.block}';
            _result = 'Data berhasil ditulis.';
            break;
          case NfcResetSuccess():
            _status = 'Kartu Berhasil Direset!';
            _result = '${event.sectorsReset} sektor telah dikosongkan.';
            break;
          case NfcError():
            _status = 'Error: ${event.errorCode}';
            _result = event.errorMessage;
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    _nfcModule.dispose();
    super.dispose();
  }

  void _cancel() async {
    await _nfcModule.cancelOperation();
    setState(() {
      _status = 'Operasi dibatalkan. Siap untuk perintah baru.';
      _result = '-';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Read/Write Block')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Result Panel
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_result),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.restore_page_outlined),
                label: const Text('Reset Kartu ke Pabrikan'),
                onPressed: _prepareReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Batalkan Operasi'),
                onPressed: _cancel,
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
