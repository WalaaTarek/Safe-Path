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

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;

  FlutterTts flutterTts = FlutterTts();

  String description = "";
  bool isProcessing = false;

  Timer? timer;

 
  String lastSpoken = "";
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    initCamera();

    flutterTts.setLanguage('en-US');
    flutterTts.setSpeechRate(0.5);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);

    flutterTts.setQueueMode(0);

    flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });

    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!isProcessing) {
        detect();
      }
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

  Future<void> detect() async {
    if (!controller.value.isInitialized) return;

    try {
      isProcessing = true;

      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.3:8000/detect'),
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

      print("DESCRIPTION: $newDescription");

      setState(() {
        description = newDescription;
      });

 
      if (newDescription.isNotEmpty &&
          newDescription != lastSpoken &&
          !isSpeaking) {

        lastSpoken = newDescription;
        isSpeaking = true;

        await flutterTts.speak(newDescription);
      }

    } catch (e) {
      print("ERROR: $e");
    }

    isProcessing = false;
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    flutterTts.stop();
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