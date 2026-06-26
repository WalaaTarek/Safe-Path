import 'dart:io';
import 'dart:convert';
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

class _UploadScreenState extends State<UploadScreen> {
  File? image;
  String result = "";
  bool isLoading = false;

  // translate toggle
  bool translate = false;

  final picker = ImagePicker();

  //  TTS
  FlutterTts tts = FlutterTts();

  // speak function
  Future speak(String text) async {
    if (text.isEmpty) return;
    await tts.setLanguage("en-US"); 
    await tts.setSpeechRate(0.5);
    await tts.speak(text);
  }

  Future pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
        result = "";
      });
    }
  }

  Future uploadImage() async {
    if (image == null) return;

    setState(() => isLoading = true);

    try {
      var uri = Uri.parse(ApiConfig.ocr);

      var request = http.MultipartRequest("POST", uri);

      request.files.add(await http.MultipartFile.fromPath(
        "file",
        image!.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      // 🌍 send translate flag
      request.fields["translate"] = translate.toString();

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      final data = jsonDecode(respStr);

      setState(() {
        result = data["text"] ?? data["error"] ?? "No result";
      });

      speak(result);

    } catch (e) {
      setState(() {
        result = "Error: $e";
      });
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // 📷 Image Card
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                    )
                  ],
                ),
                child: image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(image!, fit: BoxFit.cover),
                      )
                    : const Center(
                        child: Text(
                          "No Image Selected",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // 📁 Pick Button
              ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pick Image"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 🌍 Translate Switch
              SwitchListTile(
                title: const Text("Translate to Arabic"),
                value: translate,
                activeColor: Colors.deepPurple,
                onChanged: (value) {
                  setState(() {
                    translate = value;
                  });
                },
              ),

              // ⬆ Upload Button
              ElevatedButton.icon(
                onPressed: isLoading ? null : uploadImage,
                icon: const Icon(Icons.cloud_upload),
                label: Text(isLoading ? "Processing..." : "Upload"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ⏳ Loader
              if (isLoading)
                const CircularProgressIndicator(),

              const SizedBox(height: 20),

              // 📄 Result Box
              if (result.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Text(
                    result,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}