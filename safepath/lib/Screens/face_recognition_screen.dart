import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http_parser/http_parser.dart';

class FaceRecognitionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FaceRecognitionScreen({super.key, required this.cameras});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  bool _isControllerDisposed = false;
  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText speech = SpeechToText();

  Timer? recognitionTimer;
  bool isProcessing = false;
  bool isVoiceInteracting = false;
  String detectedName = "Scanning Face...";
  String status = "Safe-Path Active";

  final String baseUrl = "http://192.168.100.15:8000";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initTts();
    initSpeech();
    initCamera();
  }

  Future<void> initSpeech() async {
    await speech.initialize();
  }

  Future<void> initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<void> initCamera() async {
    if (widget.cameras.isEmpty) return;

    if (controller != null) {
      _isControllerDisposed = true;
      await controller!.dispose();
    }

    controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();
      _isControllerDisposed = false;
      if (mounted) {
        setState(() {});
      }
      startRecognitionLoop();
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }

  bool _isLoopRunning = false;

  void startRecognitionLoop() async {
    if (_isLoopRunning) return;
    _isLoopRunning = true;

    while (mounted && !_isControllerDisposed) {
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted || isVoiceInteracting || isProcessing) continue;
      if (controller == null || !controller!.value.isInitialized) continue;

      await recognizeFace();
    }
    _isLoopRunning = false;
  }

  Future<void> speak(String text) async {
    Completer<void> completer = Completer<void>();

    flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    flutterTts.setErrorHandler((msg) {
      if (!completer.isCompleted) completer.completeError(msg);
    });

    await flutterTts.speak(text);
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  Future<String> listenOnce() async {
    if (speech.isListening) return "";

    Completer<String> completer = Completer();
    bool available = await speech.initialize();

    if (!available) return "";

    speech.listen(
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords.toLowerCase());
        }
      },
    );

    String result = await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        speech.stop();
        return "";
      },
    );

    await speech.stop();
    return result;
  }

  Future<void> handleUnknownFace(Uint8List imageBytes) async {
    isVoiceInteracting = true;

    recognitionTimer?.cancel();

    if (mounted) {
      setState(() {
        detectedName = "Unknown Face";

        status = "Voice prompt active...";
      });
    }

    await speak(
      "I don't recognize this person. "
      "Would you like to save this face?"
      "Say yes or no.",
    );

    String answer = await listenOnce();

    debugPrint("User Answer: $answer");

    if (answer.contains("yes") || answer.contains("yeah")) {
      await speak("Please tell me the person's name.");

      String personName = await listenOnce();

      debugPrint(
        "Person Name Captured: "
        "$personName",
      );

      if (personName.isEmpty) {
        await speak(
          "Sorry, I couldn't hear the name clearly. Please try again.",
        );

        isVoiceInteracting = false;

        startRecognitionLoop();

        return;
      }

      await speak(
        "Please provide a short description "
        "for this person.",
      );

      String description = await listenOnce();

      debugPrint(
        "Description Captured: "
        "$description",
      );

      if (description.isEmpty) {
        description = "No description";
      }

      await savePerson(personName, description, imageBytes);
    } else {
      await speak("Person not saved.");
    }

    isVoiceInteracting = false;

    startRecognitionLoop();
  }

  Future<void> handleKnownFace(
    String documentId,
    String personName,
    String description,
  ) async {
    isVoiceInteracting = true;

    recognitionTimer?.cancel();

    await speak("$personName recognized.");

    await speak(
      "Would you like to edit or delete this person? "
      "Say edit, delete, or no.",
    );

    String action = await listenOnce();

    debugPrint("Action: $action");

    if (action.contains("edit")) {
      await speak("Would you like to edit name or description?");

      String choice = await listenOnce();

      if (choice.contains("name")) {
        await speak("Please say the new name.");

        String newName = await listenOnce();

        if (newName.isNotEmpty) {
          await updatePerson(documentId, newName, "");

          if (mounted) {
            setState(() {
              detectedName = newName;
              status = "Name Updated";
            });
          }
        }
      } else if (choice.contains("description")) {
        await speak("Please say the new description.");

        String newDescription = await listenOnce();

        if (newDescription.isNotEmpty) {
          await updatePerson(documentId, "", newDescription);

          if (mounted) {
            setState(() {
              status = "Description Updated";
            });
          }
        }
      } else {
        await speak("Invalid option.");
      }
    } else if (action.contains("delete")) {
      await speak(
        "Are you sure you want to delete "
        "$personName ? "
        "Say yes or no.",
      );

      String confirm = await listenOnce();

      if (confirm.contains("yes")) {
        await deletePerson(documentId);

        if (mounted) {
          setState(() {
            detectedName = "Deleted";
            status = "$personName removed";
          });
        }
      } else {
        await speak("Delete cancelled.");
      }
    } else {
      await speak("Okay.");
    }

    isVoiceInteracting = false;

    startRecognitionLoop();
  }

  Future<void> savePerson(
    String name,

    String description,

    Uint8List bytes,
  ) async {
    try {
      var request = http.MultipartRequest(
        "POST",

        Uri.parse("$baseUrl/face-recognition/save-new-face"),
      );

      request.fields["name"] = name;

      request.fields["description"] = description;

      request.files.add(
        http.MultipartFile.fromBytes("file", bytes, filename: "face.jpg"),
      );

      var response = await request.send();

      var responseString = await response.stream.bytesToString();

      debugPrint(
        "Save Response: "
        "$responseString",
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            detectedName = name;

            status = "Saved Successfully";
          });
        }

        await speak("$name has been saved successfully.");
      } else {
        await speak(
          "Failed to save person "
          "on the server.",
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");

      await speak(
        "Error while communicating "
        "with the server.",
      );
    }
  }

  Future<void> recognizeFace() async {
    if (controller == null ||
        !controller!.value.isInitialized ||
        _isControllerDisposed) {
      return;
    }

    if (isProcessing || isVoiceInteracting) {
      return;
    }

    try {
      isProcessing = true;

      final XFile file = await controller!.takePicture();
      Uint8List bytes = await file.readAsBytes();

      if (!mounted || isVoiceInteracting) return;

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/face-recognition/recognize-face"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: "frame.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );

      var response = await request.send().timeout(const Duration(seconds: 7));

      var responseString = await response.stream.bytesToString();

      debugPrint("Server Raw Response: $responseString");

      var data = jsonDecode(responseString);

      if (!mounted || isVoiceInteracting) return;

      if (response.statusCode == 200) {
        String resStatus = data["status"];

        if (resStatus == "no_face") {
          setState(() {
            detectedName = "Scanning...";
            status = "No face detected in frame";
          });

          return;
        } else if (resStatus == "known") {
          String documentId = data["document_id"];

          String personName = data["name"];

          String description = data["description"] ?? "";

          setState(() {
            detectedName = personName;
            status = "Verified: $personName";
          });

          await handleKnownFace(documentId, personName, description);
        } else if (resStatus == "unknown") {
          await handleUnknownFace(bytes);
        }
      } else {
        setState(() {
          detectedName = "Server Error";
          status = "Code: ${response.statusCode}";
        });
      }
    } catch (e) {
      debugPrint("Error in recognizeFace: $e");
    } finally {
      isProcessing = false;
    }
  }

  Future<void> updatePerson(
    String documentId,
    String newName,
    String newDescription,
  ) async {
    try {
      var request = http.MultipartRequest(
        "PUT",
        Uri.parse("$baseUrl/face-recognition/update-face"),
      );

      request.fields["document_id"] = documentId;

      if (newName.isNotEmpty) {
        request.fields["new_name"] = newName;
      }

      if (newDescription.isNotEmpty) {
        request.fields["new_description"] = newDescription;
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        await speak("Person updated successfully");
      } else {
        await speak("Failed to update person");
      }
    } catch (e) {
      debugPrint("Update Error: $e");

      await speak("Error updating person");
    }
  }

  Future<void> deletePerson(String documentId) async {
    try {
      var response = await http.delete(
        Uri.parse(
          "$baseUrl/face-recognition/delete-face?document_id=$documentId",
        ),
      );

      if (response.statusCode == 200) {
        await speak("Person deleted successfully");
      } else {
        await speak("Failed to delete person");
      }
    } catch (e) {
      debugPrint("Delete Error: $e");

      await speak("Error deleting person");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      recognitionTimer?.cancel();
      _isControllerDisposed = true;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recognitionTimer?.cancel();
    _isControllerDisposed = true;
    controller?.dispose();
    flutterTts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null ||
        !controller!.value.isInitialized ||
        _isControllerDisposed) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(controller!)),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Semantics(
              label: detectedName.isEmpty ? "Scanning Face" : detectedName,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      detectedName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
