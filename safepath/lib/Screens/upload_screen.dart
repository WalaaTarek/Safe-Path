import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:Safepath/config/api_config.dart';

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0D47A1),
        letterSpacing: 0.8,
      ),
    ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D47A1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D47A1).withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "OCR Scanner",
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Extract text from images instantly",
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                _glassContainer(
                  height: 200,
                  padding: EdgeInsets.zero,
                  child: image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
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
                                size: 34,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "No image selected yet",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0D47A1),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text(
                      "Pick Image from Gallery",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side: const BorderSide(
                        color: Color(0xFFBBDEFB),
                        width: 1.2,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      shadowColor: const Color(0xFF0D47A1).withOpacity(0.05),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                        color: Color(0xFF0D47A1),
                        size: 18,
                      ),
                    ),
                    title: const Text(
                      "Translate to Arabic",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    value: translate,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF0D47A1),
                    inactiveTrackColor: const Color(0xFFE2E8F0),
                    onChanged: (v) => setState(() => translate = v),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF0D47A1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : uploadImage,
                    icon: const Icon(
                      Icons.cloud_upload_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      isLoading ? "Processing Data…" : "Upload and Analyse",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                if (isLoading) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D47A1),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ],

                if (result.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionLabel("Analysis Result"),
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
                                size: 18,
                                color: Color(0xFF0D47A1),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                translate ? "النص المستخرج" : "Extracted Text",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          Text(
                            result,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF334155),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
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
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.volume_up_rounded,
                                        size: 16,
                                        color: Color(0xFF0D47A1),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Read Aloud",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF0D47A1),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
