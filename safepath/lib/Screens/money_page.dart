import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:safepath/services/api_service_coins.dart';

class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key});

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  CameraController? _controller;
  Timer? _timer;

  bool _isProcessing = false;

  List<dynamic> result = [];

  FlutterTts flutterTts = FlutterTts();
  String lastSpoken = "";

  @override
  void initState() {
    super.initState();
    initCamera();
    initTts();

    Future.delayed(const Duration(seconds: 2), () async {
      await flutterTts.speak("Money detection started");
    });
  }

  void initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> initCamera() async {
    final cams = await availableCameras();
    final camera = cams.first;

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (!mounted) return;
    setState(() {});

    startStream();
  }

  void startStream() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await captureAndSend();
    });
  }

  Future<void> captureAndSend() async {
    if (_isProcessing) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    _isProcessing = true;

    try {
      final image = await _controller!.takePicture();

      final response = await ApiService.uploadImage(File(image.path));

      if (!mounted) return;

      setState(() {
        if (response is Map && response.containsKey("error")) {
          result = [];
        } else {
          result = response;
        }
      });

      await speakResult();
    } catch (e) {
      print("Capture error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> speakResult() async {
    if (result.isEmpty) return;

    String textToSpeak = "";

    for (var item in result) {
      textToSpeak += "${item["class"]} pounds. ";
    }

    if (textToSpeak == lastSpoken) return;

    lastSpoken = textToSpeak;

    await flutterTts.stop();
    await flutterTts.speak(textToSpeak);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: result.isEmpty
                    ? const Text(
                        "No detection yet",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: result.map((item) {
                          return Text(
                            "${item["class"]}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
