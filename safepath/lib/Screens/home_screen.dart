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
import 'settings_screen.dart';
import 'upload_screen.dart';

import 'package:Safepath/services/language_manager.dart';
import 'package:Safepath/services/language_string.dart';
import 'package:Safepath/config/api_config.dart';

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
    _navTts.setLanguage(LanguageManager.isArabic ? "ar-SA" : "en-US");
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
      const UploadScreen(),
      SettingsScreen(
        onLanguageChanged: () {
          setState(() {
            _initTts();
            _buildScreens();
          });
        },
      ),
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
          Uri.parse(ApiConfig.command),
        );

        request.fields['language'] = LanguageManager.isArabic ? "ar" : "en";

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
            String message =
                jsonRes['message'] ?? LanguageStrings.get("navigating");

            await _navTts.setLanguage(
              LanguageManager.isArabic ? "ar-SA" : "en-US",
            );
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
              case "upload":
                newIndex = 3;
                break;
              case "settings":
                newIndex = 4;
                break;
            }

            setState(() {
              currentIndex = newIndex;
              _buildScreens();
            });
          } else {
            String desc =
                jsonRes['description'] ??
                LanguageStrings.get("commandNotRecognized");
            await _navTts.setLanguage(
              LanguageManager.isArabic ? "ar-SA" : "en-US",
            );
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
      onLongPressStart: (_) async => await _startNavListening(),
      onLongPressEnd: (_) async => await _stopAndNavigate(),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            screens[currentIndex],

            if (_isNavRecording)
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D47A1).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            LanguageStrings.get("listening"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 9, 77, 132), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: currentIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white60,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              onTap: (index) {
                setState(() {
                  currentIndex = index;
                  _buildScreens();
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: LanguageStrings.get("camera"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.payments_outlined),
                  label: LanguageStrings.get("money"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  label: LanguageStrings.get("person"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.upload_file_outlined),
                  label: LanguageStrings.get("upload"),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  label: LanguageStrings.get("settings"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
