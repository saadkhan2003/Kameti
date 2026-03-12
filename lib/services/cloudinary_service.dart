import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
  });
}

class CloudinaryService {
  String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  bool get isConfigured => _cloudName.isNotEmpty && _uploadPreset.isNotEmpty;

  Future<CloudinaryUploadResult> uploadPaymentProof({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isConfigured) {
      throw Exception('Cloudinary is not configured in assets/env');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request =
        http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed (${streamedResponse.statusCode})',
      );
    }

    final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
    final secureUrl = jsonMap['secure_url']?.toString() ?? '';
    final publicId = jsonMap['public_id']?.toString() ?? '';

    if (secureUrl.isEmpty || publicId.isEmpty) {
      throw Exception('Invalid Cloudinary response');
    }

    return CloudinaryUploadResult(secureUrl: secureUrl, publicId: publicId);
  }
}
