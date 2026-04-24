import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late CameraController controller;
  final FlutterTts flutterTts = FlutterTts();

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

  void initTts() {
    flutterTts.setLanguage('en-US');
    flutterTts.setSpeechRate(0.5);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);

    flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });
  }

  Future<void> initCamera() async {
    controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();

    if (!mounted) return;

    setState(() {});

    startProximityDetection();

    startYoloDetectionLoop();
  }

  void startProximityDetection() {
    controller.startImageStream((CameraImage image) {
      _processFrameLocally(image);
    });
  }

  void _processFrameLocally(CameraImage image) {
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
      print("Error processing frame for proximity: $e");
    }
  }

  void _triggerProximityAlert() {
    if (_lastProximityAlert != null) {
      int diff = DateTime.now().difference(_lastProximityAlert!).inSeconds;
      if (diff < _proximityAlertCooldownSeconds) return;
    }

    _lastProximityAlert = DateTime.now();

    _vibrateHighDanger();

    if (!isSpeaking) {
      _speakImmediate("Watch out! Something is very close!", "high_danger");
    }
  }

  void startYoloDetectionLoop() {
    if (isDetectLoopRunning) return;
    isDetectLoopRunning = true;

    Future.doWhile(() async {
      if (!mounted) return false;

      bool hasHighDanger = await detectWithYolo();

      int waitSeconds = hasHighDanger
          ? _dangerIntervalSeconds
          : _normalIntervalSeconds;

      await Future.delayed(Duration(seconds: waitSeconds));

      return true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.stopImageStream();
      controller.dispose();
      flutterTts.stop();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  Future<void> _vibrateHighDanger() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;
    Vibration.vibrate(pattern: [0, 500, 100, 500, 100, 500]);
  }

  Future<void> _vibrate(String type) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    switch (type) {
      case "high_danger":
        Vibration.vibrate(pattern: [0, 500, 100, 500, 100, 500]);
        break;
      case "medium_danger":
        Vibration.vibrate(pattern: [0, 300, 200, 300]);
        break;
      case "low_danger":
        Vibration.vibrate(duration: 200);
        break;
    }
  }

  Future<void> _speakImmediate(String text, String type) async {
    await flutterTts.stop();

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

    isSpeaking = true;
    await flutterTts.speak(text);
  }

  bool _shouldSpeak(String newDescription, String newResponseType) {
    if (newDescription.isEmpty) return false;

    if (isSpeaking && newResponseType != "high_danger") return false;

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

  Future<bool> detectWithYolo() async {
    if (isProcessing) return false;
    if (!controller.value.isInitialized) return false;

    try {
      isProcessing = true;

      await controller.stopImageStream();

      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      controller.startImageStream((CameraImage image) {
        _processFrameLocally(image);
      });

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.8:8000/detect'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'frame.jpg'),
      );

      var response = await request.send();
      var resStr = await response.stream.bytesToString();
      var jsonRes = jsonDecode(resStr);

      String newDescription =
          jsonRes['description'] ?? "No description available";
      String newResponseType = jsonRes['response_type'] ?? "clear";
      bool hasHighDanger = jsonRes['has_high_danger'] ?? false;

      if (!mounted) return false;

      if (newResponseType == "high_danger") {
        SemanticsService.announce(newDescription, TextDirection.ltr);

        if (responseType != "high_danger") {
          await flutterTts.stop();
          isSpeaking = false;
        }
      }

      if (_shouldSpeak(newDescription, newResponseType)) {
        if (newResponseType != "clear" && newResponseType != "error") {
          await _vibrate(newResponseType);
        }
        await _speakImmediate(newDescription, newResponseType);
      }

      setState(() {
        description = newDescription;
        responseType = newResponseType;
      });

      return hasHighDanger;
    } catch (e) {
      print("ERROR: $e");
      if (controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        controller.startImageStream((CameraImage image) {
          _processFrameLocally(image);
        });
      }

      return false;
    } finally {
      isProcessing = false;
    }
  }

  @override
  void dispose() {
    if (controller.value.isStreamingImages) {
      controller.stopImageStream();
    }
    controller.dispose();
    flutterTts.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Scaffold(
        body: Semantics(
          label: "Loading camera, please wait",
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          ExcludeSemantics(
            child: SizedBox.expand(child: CameraPreview(controller)),
          ),

          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Semantics(
              label: description.isEmpty ? "Scanning" : description,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  description.isEmpty ? "Scanning..." : description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
