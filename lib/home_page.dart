import 'package:flutter/material.dart';
import 'package:frame_sdk/frame_sdk.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:convert';
import 'edit_wake_words_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Frame frame;
  bool isConnected = false;
  int batteryLevel = 0;
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  Map<String, String> _appWakeWords = {};
  List<Application> _installedApps = [];
  Application? _selectedApp;
  bool _isLoading = true;
  String _searchQuery = '';
  TextEditingController _wakeWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    frame = Frame();
    _initializeFrameConnection();
    _loadWakeWords();
    _loadInstalledApps();
  }

  Future<void> _initializeFrameConnection() async {
    try {
      await frame.connect();
      setState(() {
        isConnected = frame.isConnected;
      });
      if (isConnected) {
        _updateBatteryLevel();
      }
    } catch (e) {
      print("Error connecting to Frame: $e");
    }
  }

  Future<void> _updateBatteryLevel() async {
    try {
      int level = await frame.getBatteryLevel();
      setState(() {
        batteryLevel = level;
      });
    } catch (e) {
      print("Error getting battery level: $e");
    }
  }

  void _loadWakeWords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      String? appWakeWordsJson = prefs.getString('app_wake_words');
      if (appWakeWordsJson != null) {
        Map<String, dynamic> decodedMap = jsonDecode(appWakeWordsJson);
        _appWakeWords = Map<String, String>.from(decodedMap);
      } else {
        _appWakeWords = {};
      }
    });
  }

  void _saveWakeWords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_wake_words', jsonEncode(_appWakeWords));
  }

  Future<void> _loadInstalledApps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: false,
      );

      apps.sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading installed apps: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleConnection() async {
    if (isConnected) {
      await frame.disconnect();
    } else {
      await _initializeFrameConnection();
    }
    setState(() {
      isConnected = frame.isConnected;
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _startListening() async {
    if (await _speech.initialize()) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _processVoiceCommand(result.recognizedWords);
          }
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _processVoiceCommand(String command) {
    _appWakeWords.forEach((packageName, wakeWord) {
      if (command.toLowerCase().contains(wakeWord.toLowerCase())) {
        _launchApp(packageName);
      }
    });
  }

  Future<void> _launchApp(String packageName) async {
    print('Attempting to launch app: $packageName');
    try {
      bool launched = await DeviceApps.openApp(packageName);
      if (launched) {
        print('Successfully launched app: $packageName');
        await Future.delayed(Duration(seconds: 2));
        _startListening();
      } else {
        print('Failed to launch app: $packageName');
      }
    } catch (e) {
      print('Error launching app: $e');
    }
  }

  List<Application> get _filteredApps {
    return _installedApps
        .where((app) =>
            app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            app.packageName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _saveWakeWord() {
    if (_selectedApp != null && _wakeWordController.text.isNotEmpty) {
      setState(() {
        _appWakeWords[_selectedApp!.packageName] = _wakeWordController.text;
      });
      _saveWakeWords();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wake word saved for ${_selectedApp!.appName}')),
      );
      _wakeWordController.clear();
      _selectedApp = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frame Voice Command'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.yellow),
              child: Text('Menu', style: TextStyle(color: Colors.black)),
            ),
            ListTile(
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Edit Wake Words'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditWakeWordsPage(
                      appWakeWords: _appWakeWords,
                      onSave: (newAppWakeWords) {
                        setState(() {
                          _appWakeWords = newAppWakeWords;
                          _saveWakeWords();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _toggleConnection,
                child: Text(
                    isConnected ? 'Disconnect Glasses' : 'Connect Glasses'),
              ),
              const SizedBox(height: 16),
              Text('Battery Level: $batteryLevel%'),
              const SizedBox(height: 16),
              if (_selectedApp != null) ...[
                Text('Set wake word for: ${_selectedApp!.appName}',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _wakeWordController,
                  decoration: InputDecoration(
                    labelText: 'Wake Word',
                    hintText: 'Enter wake word for the selected app',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _saveWakeWord,
                  child: Text('Save Wake Word'),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _toggleListening,
                child:
                    Text(_isListening ? 'Stop Listening' : 'Start Listening'),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search Apps',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('All Installed Apps (${_installedApps.length})',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _isLoading
                  ? CircularProgressIndicator()
                  : Container(
                      height: 400,
                      child: ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          Application app = _filteredApps[index];
                          bool isSelected = _selectedApp == app;
                          String? appWakeWord = _appWakeWords[app.packageName];
                          return ListTile(
                            leading: app is ApplicationWithIcon
                                ? Image.memory(app.icon, width: 40, height: 40)
                                : Icon(Icons.android),
                            title: Text(app.appName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.packageName),
                                if (appWakeWord != null)
                                  Text('Wake word: $appWakeWord'),
                              ],
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedApp = app;
                                    _wakeWordController.text =
                                        _appWakeWords[app.packageName] ?? '';
                                  } else {
                                    _selectedApp = null;
                                    _wakeWordController.clear();
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wakeWordController.dispose();
    super.dispose();
  }
}
