import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String url = "http://192.168.1.8:5000/predict";

  static Future<dynamic> uploadImage(File img) async {
    try {
      var request = http.MultipartRequest("POST", Uri.parse(url));

      request.files.add(await http.MultipartFile.fromPath("image", img.path));

      var response = await request.send();
      var res = await http.Response.fromStream(response);

      if (response.statusCode != 200) {
        return {"error": "Server error", "status": response.statusCode};
      }

      return jsonDecode(res.body);
    } catch (e) {
      return {"error": e.toString()};
    }
  }
}
