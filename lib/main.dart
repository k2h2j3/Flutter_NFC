import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

import 'package:nfc_manager/platform_tags.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NFC Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.blueGrey[900],
      ),
      home: NfcHomePage(),
    );
  }
}

class NfcHomePage extends StatefulWidget {
  @override
  _NfcHomePageState createState() => _NfcHomePageState();
}

class _NfcHomePageState extends State<NfcHomePage> {
  String _nfcStatus = '태그를 스캔하세요';
  String _nfcId = ' ';
  String _decodedMessage = ' ';

  void updateNfcInfo(String id, String message) {
    setState(() {
      _nfcId = id;
      _decodedMessage = message;
      _nfcStatus = 'NFC 태그 읽기 성공';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC 리더'),
        backgroundColor: Colors.blue[800],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.nfc,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              _nfcStatus,
              style: TextStyle(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Card(
              color: Colors.blue[700],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'NFC ID:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    Text(
                      _nfcId,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '메시지:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    Text(
                      _decodedMessage,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.sensors),
              label: Text('NFC 스캔 시작'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => NfcService.readNfc(updateNfcInfo).then((_) {
                setState(() {
                  _nfcStatus = 'NFC 스캔 준비 완료';
                });
              }).catchError((error) {
                setState(() {
                  _nfcStatus = 'NFC 활성화 실패: $error';
                });
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class NfcService {
  static Future<void> readNfc(Function(String, String) updateCallback) async {
    bool isAvailable = await NfcManager.instance.isAvailable();

    if (!isAvailable) {
      if (Platform.isAndroid) {
        const AndroidIntent intent = AndroidIntent(
          action: 'android.settings.NFC_SETTINGS',
        );
        await intent.launch();
        return;
      }
      throw Exception('NFC is not available on this device');
    }

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        String id = _getNfcId(tag);
        String? decodedMessage = _getDecodedNfcMessage(tag);
        print('NFC ID: $id');
        print('Decoded message: $decodedMessage');

        updateCallback(id, decodedMessage ?? 'No message found');

        if (Platform.isIOS) {
          NfcManager.instance.stopSession(alertMessage: 'NFC 태그 읽기 성공');
        }
      },
      onError: (error) async {
        print('Error reading NFC: $error');
        await NfcManager.instance.stopSession(errorMessage: 'NFC 태그 읽기 실패');
      },
    );
  }

  static String _getNfcId(NfcTag tag) {
    if (Platform.isIOS) {
      var mifare = MiFare.from(tag);
      if (mifare != null) {
        return mifare.identifier
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join('');
      }
    } else {
      Ndef? ndef = Ndef.from(tag);
      if (ndef != null) {
        var identifier = ndef.additionalData['identifier'] as List<int>?;
        if (identifier != null) {
          return identifier
              .map((e) => e.toRadixString(16).padLeft(2, '0'))
              .join('');
        }
      }
    }
    return 'Unknown ID';
  }

  static String? _getDecodedNfcMessage(NfcTag tag) {
    Ndef? ndef = Ndef.from(tag);
    NdefMessage? ndefMessage = ndef?.cachedMessage;
    if (ndefMessage != null) {
      for (NdefRecord record in ndefMessage.records) {
        if (record.typeNameFormat == NdefTypeNameFormat.media ||
            record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
          if (record.type.isNotEmpty && String.fromCharCodes(record.type) == 'T') {
            var payload = record.payload;
            int languageCodeLength = payload[0] & 0x3f;
            return String.fromCharCodes(payload.sublist(1 + languageCodeLength));
          }
        }
      }
    }
    return null;
  }
}