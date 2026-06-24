import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

import 'package:Safepath/Screens/money_page.dart';
import 'camera_screen.dart';
import 'face_recognition_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  late List<Widget> screens;
  final AudioRecorder _navAudioRecorder = AudioRecorder();
  final FlutterTts _navTts = FlutterTts();
  bool _isNavRecording = false;
  String _navAudioPath = "";
  static bool isSystemNavRecording = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _buildScreens();
  }

  void _initTts() {
    _navTts.setLanguage('en-US');
    _navTts.setSpeechRate(0.5);
  }

  void _buildScreens() {
    screens = [
      CameraScreen(
        cameras: widget.cameras,
        onNavigate: (index) {
          setState(() {
            currentIndex = index;
            _buildScreens();
          });
        },
      ),
      const MoneyPage(),
      FaceRecognitionScreen(cameras: widget.cameras),
      const HistoryScreen(),
      const SettingsScreen(),
      const UploadScreen(),
    ];
  }

  Future<void> _startNavListening() async {
    try {
      if (await _navAudioRecorder.hasPermission()) {
        final directory = await Directory.systemTemp.createTemp();
        _navAudioPath = '${directory.path}/global_nav_command.wav';

        await _navAudioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _navAudioPath,
        );

        if (await Vibration.hasVibrator() == true) {
          Vibration.vibrate(duration: 100);
        }

        setState(() {
          _isNavRecording = true;
          isSystemNavRecording = true;
        });
      }
    } catch (e) {
      print("Global Nav start record error: $e");
    }
  }

  Future<void> _stopAndNavigate() async {
    try {
      final path = await _navAudioRecorder.stop();
      setState(() {
        _isNavRecording = false;
        isSystemNavRecording = false;
      });

      if (path != null) {
        final audioFile = File(path);
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.1.2:3000/command'),
        );
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            audioFile.path,
            filename: 'command.wav',
          ),
        );
        request.files.add(
          http.MultipartFile.fromBytes('image', [], filename: 'frame.jpg'),
        );

        var response = await request.send();
        if (response.statusCode == 200) {
          var resStr = await response.stream.bytesToString();
          var jsonRes = jsonDecode(resStr);

          if (jsonRes.containsKey('target_tab') &&
              jsonRes['target_tab'] != "") {
            String targetTab = jsonRes['target_tab'];
            String message = jsonRes['message'] ?? "Navigating";

            await _navTts.speak(message);

            int newIndex = currentIndex;
            switch (targetTab) {
              case "camera":
                newIndex = 0;
                break;
              case "money":
                newIndex = 1;
                break;
              case "person":
                newIndex = 2;
                break;
              case "history":
                newIndex = 3;
                break;
              case "settings":
                newIndex = 4;
                break;
              case "upload":
                newIndex = 5;
                break;
            }

            setState(() {
              currentIndex = newIndex;
              _buildScreens();
            });
          } else {
            String desc = jsonRes['description'] ?? "Command not recognized";
            await _navTts.speak(desc);
          }
        }
      }
    } catch (e) {
      print("Global Nav stop error: $e");
      setState(() {
        _isNavRecording = false;
        isSystemNavRecording = false;
      });
    }
  }

  @override
  void dispose() {
    _navAudioRecorder.dispose();
    _navTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) async {
        await _startNavListening();
      },
      onLongPressEnd: (_) async {
        await _stopAndNavigate();
      },
      child: Scaffold(
        body: Stack(
          children: [
            screens[currentIndex],

            if (_isNavRecording)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Listening... Say tab name (e.g., Money, Settings)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: const Color.fromARGB(224, 126, 126, 126),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            setState(() {
              currentIndex = index;
              _buildScreens();
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: "Camera",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monetization_on),
              label: "Money",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Person"),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: "Settings",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file),
              label: "Upload",
            ),
          ],
        ),
      ),
    );
  }
}
