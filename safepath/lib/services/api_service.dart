import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.3:8000";

  static Future<String> uploadImage(CameraController controller) async {
    try {
      final XFile file = await controller.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print("RAW RESPONSE: $responseData"); 

      if (responseData.isEmpty) {
        return "No response from server";
      }

      var jsonResponse = jsonDecode(responseData);

      
      String description =
          jsonResponse['description'] ?? "No description available";

      return description;

    } catch (e) {
      print("ApiService Error: $e");
      return "Error connecting to server";
    }
  }
}