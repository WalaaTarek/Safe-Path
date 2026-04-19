import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {

  late CameraController controller;
  FlutterTts flutterTts = FlutterTts();

  String description = "";

  bool isProcessing = false;
  bool isSpeaking = false;

  String lastSpoken = "";

  Timer? timer;
  bool isDetectLoopRunning = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    initCamera();

    initTts();

    startDetectionLoop();
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
    );

    await controller.initialize();

    if (!mounted) return;

    setState(() {});
  }

  void startDetectionLoop() {
    if (isDetectLoopRunning) return;

    isDetectLoopRunning = true;

    Future.doWhile(() async {
      if (!mounted) return false;

      await detect();

      await Future.delayed(const Duration(seconds: 4));

      return true; // keep loop running
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  Future<void> detect() async {
    if (isProcessing) return;
    if (!controller.value.isInitialized ||
        controller.value.isTakingPicture) return;

    try {
      isProcessing = true;

      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.11:8000/detect'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'frame.jpg',
        ),
      );

      var response = await request.send();
      var resStr = await response.stream.bytesToString();

      var jsonRes = jsonDecode(resStr);

      String newDescription =
          jsonRes['description'] ?? "No description available";

      if (!mounted) return;

      setState(() {
        description = newDescription;
      });

      print("DESCRIPTION: $newDescription");

      if (newDescription.isNotEmpty &&
          newDescription != lastSpoken &&
          !isSpeaking) {

        lastSpoken = newDescription;
        isSpeaking = true;

        await flutterTts.stop(); 
        await flutterTts.speak(newDescription);
      }

    } catch (e) {
      print("ERROR: $e");
    } finally {
      isProcessing = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    flutterTts.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Blind Assist")),

      body: Stack(
        children: [
          CameraPreview(controller),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Text(
                description.isEmpty
                    ? "No scene detected"
                    : description,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}