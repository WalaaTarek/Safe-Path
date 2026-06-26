import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:record/record.dart';

import 'package:Safepath/services/language_manager.dart';
import 'package:Safepath/config/api_config.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(int) onNavigate;

  const CameraScreen({
    super.key,
    required this.cameras,
    required this.onNavigate,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? controller; 
  final FlutterTts flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String _audioPath = "";

  String description = "";
  String responseType = "clear";

  bool isProcessing = false;
  bool isSpeaking = false;
  bool isDetectLoopRunning = false;

  double? _lastBrightness;
  DateTime? _lastProximityAlert;
  static const double _brightnessThreshold = 30.0;
  static const int _proximityAlertCooldownSeconds = 1;
  DateTime? _lastHighDangerSpoken;

  static const int _normalIntervalSeconds = 4;
  static const int _dangerIntervalSeconds = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
    initTts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      setState(() {
        _isCameraInitialized = false;
      });
      cameraController.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  void initTts() {
    flutterTts.setLanguage(LanguageManager.isArabic ? "ar-SA" : "en-US");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> updateTtsLanguage() async {
    await flutterTts.setLanguage(LanguageManager.isArabic ? "ar-SA" : "en-US");
  }

  Future<void> initCamera() async {
    if (widget.cameras.isEmpty) return;

    controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      startProximityDetection();
      startYoloDetectionLoop();
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  void startProximityDetection() {
    if (controller == null || !controller!.value.isInitialized) return;
    
    controller!.startImageStream((CameraImage image) {
      _processFrameLocally(image);
    });
  }

  void _processFrameLocally(CameraImage image) {
    if (!_isCameraInitialized || controller == null) return;
    try {
      final Uint8List yPlane = image.planes[0].bytes;
      int total = 0;
      const int step = 10;
      int count = 0;

      for (int i = 0; i < yPlane.length; i += step) {
        total += yPlane[i];
        count++;
      }

      double currentBrightness = total / count;

      if (_lastBrightness != null) {
        double diff = (currentBrightness - _lastBrightness!).abs();
        if (diff > _brightnessThreshold) {
          _triggerProximityAlert();
        }
      }
      _lastBrightness = currentBrightness;
    } catch (e) {
      print("Brightness error: $e");
    }
  }

  void _triggerProximityAlert() {
    if (_lastProximityAlert != null) {
      int diff = DateTime.now().difference(_lastProximityAlert!).inSeconds;
      if (diff < _proximityAlertCooldownSeconds) {
        return;
      }
    }

    _lastProximityAlert = DateTime.now();
    _vibrateHighDanger();

    if (!isSpeaking) {
      _speakImmediate(
        LanguageManager.isArabic ? "انتبه، يوجد شيء قريب جداً" : "Watch out! Something is very close!",
        "high_danger",
      );
    }
  }

  void startYoloDetectionLoop() {
    if (isDetectLoopRunning) return;
    isDetectLoopRunning = true;

    Future.doWhile(() async {
      if (!mounted) return false;

      if (_isRecording || !_isCameraInitialized || controller == null) {
        await Future.delayed(const Duration(seconds: 1));
        return true;
      }

      bool danger = await detectWithYolo();
      await Future.delayed(
        Duration(seconds: danger ? _dangerIntervalSeconds : _normalIntervalSeconds),
      );
      return true;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await Directory.systemTemp.createTemp();
        _audioPath = '${directory.path}/command.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _audioPath,
        );

        setState(() {
          _isRecording = true;
          description = LanguageManager.isArabic ? "استمع الآن" : "Listening...";
        });
      }
    } catch (e) {
      print("Recording start error: $e");
    }
  }

  Future<void> _speakImmediate(String text, String type) async {
    await flutterTts.stop();
    await updateTtsLanguage();

    switch (type) {
      case "high_danger":
        await flutterTts.setPitch(1.6);
        await flutterTts.setSpeechRate(0.7);
        break;
      case "medium_danger":
        await flutterTts.setPitch(1.3);
        await flutterTts.setSpeechRate(0.6);
        break;
      case "low_danger":
        await flutterTts.setPitch(1.1);
        await flutterTts.setSpeechRate(0.55);
        break;
      default:
        await flutterTts.setPitch(1.0);
        await flutterTts.setSpeechRate(0.5);
    }

    setState(() {
      isSpeaking = true;
    });
    await flutterTts.speak(text);
  }

  bool _shouldSpeak(String newDescription, String newResponseType) {
    if (newDescription.isEmpty) return false;

    if (isSpeaking && newResponseType != "high_danger") {
      return false;
    }

    if (newResponseType == "high_danger") {
      if (_lastHighDangerSpoken == null ||
          DateTime.now().difference(_lastHighDangerSpoken!).inSeconds >= 4) {
        _lastHighDangerSpoken = DateTime.now();
        return true;
      }
      return false;
    }
    return newDescription != description;
  }

  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null && _isCameraInitialized && controller != null && controller!.value.isInitialized) {
        final image = await controller!.takePicture();
        final imageBytes = await image.readAsBytes();
        
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConfig.command),
        );

        request.fields['language'] = LanguageManager.isArabic ? "ar" : "en";

        request.files.add(
          http.MultipartFile.fromBytes('image', imageBytes, filename: 'frame.jpg'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('audio', path, filename: 'command.wav'),
        );

        var response = await request.send();
        var responseText = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseText);

        if (jsonResponse.containsKey("target_tab")) {
          String targetTab = jsonResponse["target_tab"];
          String message = jsonResponse["message"] ?? (LanguageManager.isArabic ? "جاري الفتح" : "Opening");

          await _speakImmediate(message, "clear");

          int index = 0;
          switch (targetTab) {
            case "camera": index = 0; break;
            case "money": index = 1; break;
            case "person": index = 2; break;
            case "history": index = 3; break;
            case "settings": index = 4; break;
            case "upload": index = 5; break;
          }
          widget.onNavigate(index);
          return;
        }

        String newDescription = jsonResponse["description"] ?? "";
        String newType = jsonResponse["response_type"] ?? "clear";

        await _speakImmediate(newDescription, newType);

        if (mounted) {
          setState(() {
            description = newDescription;
            responseType = newType;
          });
        }
      }
    } catch (e) {
      print("Voice command error: $e");
    }
  }

  Future<void> _vibrateHighDanger() async {
    bool? has = await Vibration.hasVibrator();
    if (has == true) {
      Vibration.vibrate(pattern: [0, 500, 100, 500]);
    }
  }

  Future<void> _vibrate(String type) async {
    bool? has = await Vibration.hasVibrator();
    if (has != true) return;

    switch (type) {
      case "high_danger":
        Vibration.vibrate(pattern: [0, 500, 100, 500]);
        break;
      case "medium_danger":
        Vibration.vibrate(pattern: [0, 300, 200, 300]);
        break;
      case "low_danger":
        Vibration.vibrate(duration: 200);
        break;
    }
  }

  Future<bool> detectWithYolo() async {
    if (isProcessing) return false;
    if (!_isCameraInitialized || controller == null || !controller!.value.isInitialized) return false;

    try {
      isProcessing = true;
      
      final picture = await controller!.takePicture();
      final bytes = await picture.readAsBytes();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.detect),
      );

      request.fields['language'] = LanguageManager.isArabic ? "ar" : "en";

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: "frame.jpg"),
      );

      var response = await request.send();
      var responseText = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseText);

      String newDescription = jsonResponse["description"] ?? "";
      String newType = jsonResponse["response_type"] ?? "clear";
      bool danger = jsonResponse["has_high_danger"] ?? false;

      if (_shouldSpeak(newDescription, newType)) {
        if (newType != "clear" && newType != "error") {
          await _vibrate(newType);
        }
        await _speakImmediate(newDescription, newType);
      }

      if (mounted) {
        setState(() {
          description = newDescription;
          responseType = newType;
        });
      }
      return danger;
    } catch (e) {
      print("YOLO ERROR $e");
      return false;
    } finally {
      isProcessing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (controller != null) {
      controller!.dispose();
    }
    _audioRecorder.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Transform.scale(
            scale: 1 / (controller!.value.aspectRatio * MediaQuery.of(context).size.aspectRatio),
            alignment: Alignment.topCenter,
            child: CameraPreview(controller!),
          ),

          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopAndSendRecording(),
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          Positioned(
            bottom: bottomPadding + 35, 
            left: 25,
            right: 25,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Text(
                  _isRecording 
                      ? description 
                      : (description.isEmpty 
                          ? (LanguageManager.isArabic ? "إضغط مطولاً للتحدث" : "Hold to speak") 
                          : description),
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}