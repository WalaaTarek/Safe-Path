import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(BlindAssistApp());
}

class BlindAssistApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;

  List objects = [];

  FlutterTts flutterTts = FlutterTts();

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    initCamera();

    flutterTts.setLanguage('en-US');
    flutterTts.setSpeechRate(0.5);

  
    Timer.periodic(Duration(milliseconds: 1500), (_) {
      if (!isProcessing) {
        detect();
      }
    });
  }

  Future<void> initCamera() async {
    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> detect() async {
    try {
      isProcessing = true;

      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.2:8000/detect'),
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

      List newObjects = jsonRes['objects'] ?? [];

      setState(() {
        objects = newObjects;
      });

      print("DETECTED: $newObjects");

      if (newObjects.isNotEmpty) {
        String text = newObjects.join(', ');
        flutterTts.speak(text);
      }

    } catch (e) {
      print("ERROR: $e");
    }

    isProcessing = false;
  }

  @override
  void dispose() {
    controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Blind Assist")),
      body: Stack(
        children: [
          CameraPreview(controller),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              color: Colors.black54,
              child: Text(
                objects.isEmpty
                    ? "No objects detected"
                    : objects.join(', '),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}