import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImageModel {
  String? imagePath;

  ImageModel({this.imagePath});
}

final http.Client _client = http.Client();

Future<String?> uploadToCloudinary(File imagePath) async {
  try {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/dxkqhwllg/upload');

    var request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'Event management'
      ..files.add(await http.MultipartFile.fromPath('file', imagePath.path));

    var streamedResponse = await _client.send(request);
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body);
      return jsonMap['secure_url'] as String;
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error uploading image: $e');
  }
}
