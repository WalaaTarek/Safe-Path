import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:Safepath/config/api_config.dart';
import 'package:Safepath/services/language_string.dart';
import '../services/language_string.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  File? image;
  String result = "";
  bool isLoading = false;
  bool translate = false;

  final picker = ImagePicker();
  final FlutterTts tts = FlutterTts();

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _fadeCtrl,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _fadeCtrl.dispose();
    tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await tts.setLanguage(translate ? "ar-SA" : "en-US");
    await tts.setSpeechRate(0.5);
    await tts.speak(text);
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        image = File(picked.path);
        result = "";
      });
      _fadeCtrl.reset();
    }
  }

  Future<void> uploadImage() async {
    if (image == null) return;
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse(ApiConfig.ocr);
      final request = http.MultipartRequest("POST", uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          image!.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      request.fields["translate"] = translate.toString();

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);

      setState(() => result = data["text"] ?? data["error"] ?? "No result");
      _fadeCtrl.forward(from: 0);
      await _speak(result);
    } catch (e) {
      setState(() => result = "Error: $e");
      _fadeCtrl.forward(from: 0);
    }
    setState(() => isLoading = false);
  }

  Widget _glassContainer({
    required Widget child,
    double? height,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: height,
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  ButtonStyle _btnStyle() => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF1565C0),
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 55),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    elevation: 2,
    shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Header Block
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1565C0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LanguageStrings.get("ocrScanner"),
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),

                  _glassContainer(
                    height: 200,
                    padding: EdgeInsets.zero,
                    child: image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(image!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE3F2FD),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.image_search_rounded,
                                  size: 40,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                LanguageStrings.get("noImageSelected"),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color.fromARGB(197, 43, 48, 55),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(LanguageStrings.get("pickImage")),
                    style: _btnStyle(),
                  ),
                  const SizedBox(height: 14),

                  _glassContainer(
                    padding: EdgeInsets.zero,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      secondary: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.translate_rounded,
                          color: Color(0xFF1565C0),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        LanguageStrings.get("translateToArabic"),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color.fromARGB(197, 43, 48, 55),
                        ),
                      ),
                      value: translate,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF1565C0),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      onChanged: (v) => setState(() => translate = v),
                    ),
                  ),
                  const SizedBox(height: 14),

                  ElevatedButton.icon(
                    onPressed: isLoading ? null : uploadImage,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      isLoading
                          ? LanguageStrings.get("processing")
                          : LanguageStrings.get("uploadBtn"),
                    ),
                    style: _btnStyle(),
                  ),

                  if (isLoading) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      color: Color(0xFF1565C0),
                      strokeWidth: 3,
                    ),
                  ],

                  if (result.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: _glassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.article_rounded,
                                  size: 20,
                                  color: Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  translate
                                      ? LanguageStrings.get("extractedText")
                                      : LanguageStrings.get("result"),
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: Color(0xFFE2E8F0)),
                            Text(
                              result,
                              style: const TextStyle(
                                color: Color.fromARGB(197, 43, 48, 55),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _speak(result),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFBBDEFB),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.volume_up_rounded,
                                          size: 16,
                                          color: Color(0xFF1565C0),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          LanguageStrings.get("readAloud"),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1565C0),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
