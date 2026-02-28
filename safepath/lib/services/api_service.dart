import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String serverUrl = "http://192.168.1.4:8000/analyze";

  static Future<String?> uploadImage(CameraController controller) async {
    try {
      final XFile file = await controller.takePicture();

      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (responseData.isEmpty) {
        return "No response from server";
      }
      var jsonResponse = jsonDecode(responseData);
      return (jsonResponse['description'] as String?) ?? "No objects detected";
    } catch (e) {
      print("Error in ApiService: $e");
      return "Error: $e";
    }
  }
}
