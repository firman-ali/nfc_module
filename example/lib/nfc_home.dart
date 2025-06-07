import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_module/nfc_module.dart';

import 'nfc_read_multiple_data_screen.dart';
import 'nfc_read_write_screen.dart';
import 'nfc_reset_screen.dart';

class NfcHome extends StatefulWidget {
  const NfcHome({super.key});

  @override
  State<NfcHome> createState() => _NfcHomeState();
}

class _NfcHomeState extends State<NfcHome> {
  String _platformVersion = 'Unknown';
  final _nfcModulePlugin = NfcModule();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _nfcModulePlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: Column(
        children: [
          Center(child: Text('Running on: $_platformVersion\n')),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NfcReadWriteScreen(),
                ),
              );
            },
            child: Text("NFC Read Write Page"),
          ),
          SizedBox(height: 16.0),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NfcResetScreen()),
              );
            },
            child: Text("NFC Reset Page"),
          ),
          SizedBox(height: 16.0),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NfcReadMultipleDataScreen(),
                ),
              );
            },
            child: Text("NFC Multiple Read Data Page"),
          ),
        ],
      ),
    );
  }
}
