import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http_parser/http_parser.dart';
import 'package:Safepath/config/api_config.dart';
import 'package:Safepath/services/language_manager.dart';
import 'package:Safepath/services/language_string.dart';

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
  String detectedName = "";
  String status = "";

  final String baseUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    detectedName = LanguageStrings.get("scanningFace");
    status = LanguageStrings.get("active");
    initTts();
    initSpeech();
    initCamera();
  }

  Future<void> initSpeech() async {
    await speech.initialize();
  }

  Future<void> initTts() async {
    await flutterTts.setLanguage(LanguageManager.isArabic ? "ar" : "en-US");
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
      localeId: LanguageManager.isArabic ? "ar-EG" : "en-US",
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
        detectedName = LanguageStrings.get("unknownFace");
        status = LanguageStrings.get("voiceActive");
      });
    }

    await speak(LanguageStrings.get("askSaveFace"));
    String answer = await listenOnce();

    if (answer.contains("yes") ||
        answer.contains("yeah") ||
        answer.contains("نعم") ||
        answer.contains("ايوه")) {
      await speak(LanguageStrings.get("askName"));
      String personName = await listenOnce();

      if (personName.isEmpty) {
        await speak(LanguageStrings.get("errorHearName"));
        isVoiceInteracting = false;
        startRecognitionLoop();
        return;
      }

      await speak(LanguageStrings.get("askDescription"));
      String description = await listenOnce();

      if (description.isEmpty) {
        description = LanguageStrings.get("noDescription");
      }

      await savePerson(personName, description, imageBytes);
    } else {
      await speak(LanguageStrings.get("notSaved"));
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

    await speak(
      LanguageManager.isArabic
          ? "تم التعرف على $personName"
          : "$personName ${LanguageStrings.get("recognized")}",
    );
    await speak(LanguageStrings.get("askAction"));
    String action = await listenOnce();

    if (action.contains("edit") || action.contains("تعديل")) {
      await speak(LanguageStrings.get("askEditChoice"));
      String choice = await listenOnce();

      if (choice.contains("name") || choice.contains("الاسم")) {
        await speak(LanguageStrings.get("askNewName"));
        String newName = await listenOnce();

        if (newName.isNotEmpty) {
          await updatePerson(documentId, newName, "");
          if (mounted) {
            setState(() {
              detectedName = newName;
              status = LanguageStrings.get("nameUpdated");
            });
          }
        }
      } else if (choice.contains("description") || choice.contains("الوصف")) {
        await speak(LanguageStrings.get("askNewDescription"));
        String newDescription = await listenOnce();

        if (newDescription.isNotEmpty) {
          await updatePerson(documentId, "", newDescription);
          if (mounted) {
            setState(() {
              status = LanguageStrings.get("descriptionUpdated");
            });
          }
        }
      } else {
        await speak(LanguageStrings.get("invalidOption"));
      }
    } else if (action.contains("delete") || action.contains("حذف")) {
      await speak(
        LanguageManager.isArabic
            ? "هل أنت متأكد أنك تريد حذف $personName ؟ قل نعم أو لا."
            : "${LanguageStrings.get("askDeleteConfirm")} $personName ?",
      );
      String confirm = await listenOnce();

      if (confirm.contains("yes") ||
          confirm.contains("نعم") ||
          confirm.contains("ايوه")) {
        await deletePerson(documentId);
        if (mounted) {
          setState(() {
            detectedName = LanguageStrings.get("deleted");
            status = LanguageManager.isArabic
                ? "تم إزالة $personName"
                : "$personName ${LanguageStrings.get("removed")}";
          });
        }
      } else {
        await speak(LanguageStrings.get("deleteCancelled"));
      }
    } else {
      await speak(LanguageStrings.get("okay"));
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
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            detectedName = name;
            status = LanguageStrings.get("saveSuccess");
          });
        }
        await speak(
          LanguageManager.isArabic
              ? "تم حفظ $name بنجاح."
              : "$name ${LanguageStrings.get("saveSuccess")}",
        );
      } else {
        await speak(LanguageStrings.get("saveFailed"));
      }
    } catch (e) {
      await speak(LanguageStrings.get("connectionError"));
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
      var data = jsonDecode(responseString);

      if (!mounted || isVoiceInteracting) return;

      if (response.statusCode == 200) {
        String resStatus = data["status"];

        if (resStatus == "no_face") {
          setState(() {
            detectedName = LanguageStrings.get("scanningFace");
            status = LanguageStrings.get("noFaceFrame");
          });
          return;
        } else if (resStatus == "known") {
          String documentId = data["document_id"];
          String personName = data["name"];
          String description = data["description"] ?? "";

          setState(() {
            detectedName = personName;
            status = "${LanguageStrings.get("verified")}: $personName";
          });

          await handleKnownFace(documentId, personName, description);
        } else if (resStatus == "unknown") {
          await handleUnknownFace(bytes);
        }
      } else {
        setState(() {
          detectedName = LanguageStrings.get("serverError");
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
        await speak(LanguageStrings.get("updateSuccess"));
      } else {
        await speak(LanguageStrings.get("updateFailed"));
      }
    } catch (e) {
      await speak(LanguageStrings.get("connectionError"));
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
        await speak(LanguageStrings.get("deleteSuccess"));
      } else {
        await speak(LanguageStrings.get("connectionError"));
      }
    } catch (e) {
      await speak(LanguageStrings.get("connectionError"));
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

    final double bottomPadding =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight - 15;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(controller!)),
          Positioned(
            bottom: bottomPadding,
            left: 16,
            right: 16,
            child: Semantics(
              label: detectedName.isEmpty
                  ? LanguageStrings.get("scanningFace")
                  : detectedName,
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
