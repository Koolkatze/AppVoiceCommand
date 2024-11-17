import 'package:flutter/material.dart';
//import 'package:frame_sdk/frame_sdk.dart';
import 'package:frame_sdk/bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BrilliantBluetooth.requestPermission();
  await Permission.storage.request();
  await Permission.microphone.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Voice Command',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.yellow,
      ),
      home: const HomePage(),
    );
  }
}
