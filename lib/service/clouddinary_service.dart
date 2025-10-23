// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:test_databse/service/db_service.dart';

// Future<bool> uploadTocloud(FilePickerResult? filePickerResult) async {
//   if (filePickerResult == null || filePickerResult.files.isEmpty) {
//     print("no file selected!");
//     return false;
//   }
//   File file = File(filePickerResult.files.single.path!);
//   String cloundName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
//   var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloundName/raw/upload");
//   var request = http.MultipartRequest("POST", uri);
//   var fileByte = await file.readAsBytes();
//   var multipartFile = http.MultipartFile.fromBytes(
//     'file',
//     fileByte,
//     filename: file.path.split("/").last,
//   );
//   request.files.add(multipartFile);
//   request.fields['upload_preset'] = "profile_upload";
//   // request.fields['upload_preset'] = "res";
//   var response = await request.send();
//   var responseBody = await response.stream.bytesToString();

//   print(responseBody);

//   if (response.statusCode == 200) {
//     var jsonResponse = jsonDecode(responseBody);
//     Map<String, String> requiredData = {
//       "name": jsonResponse["display_name"] ?? "",
//       "id": jsonResponse["public_id"] ?? "",
//       "extension": jsonResponse["resource_type"] ?? "",
//       "size": jsonResponse["bytes"].toString(),
//       "url": jsonResponse["secure_url"] ?? "",
//       "created_at": jsonResponse["created_at"] ?? "",
//     };

//     await DbService().saveUploadedFilesData(requiredData);
//     print("Upload successful");
//     return true;
//   } else {
//     print("Upload faild with status: ${response.statusCode}");
//     return false;
//   }
// }
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<String?> uploadTocloud(FilePickerResult? filePickerResult) async {
  if (filePickerResult == null || filePickerResult.files.isEmpty) {
    print("No file selected!");
    return null;
  }

  File file = File(filePickerResult.files.single.path!);

  final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'daiiibnkg';
  final uploadPreset =
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'image_profile';

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/daiiibnkg/image/upload",
  );

  var request = http.MultipartRequest('POST', url);

  var multipartFile = await http.MultipartFile.fromPath('file', file.path);

  request.files.add(multipartFile);
  request.fields['upload_preset'] = uploadPreset;

  var response = await request.send();
  var responseBody = await response.stream.bytesToString();

  print("STATUS: ${response.statusCode}");
  print("BODY: $responseBody");

  if (response.statusCode == 200) {
    final jsonResponse = jsonDecode(responseBody);
    final imageUrl = jsonResponse['secure_url'];
    print("✅ Upload successful: $imageUrl");
    return imageUrl; // ✅ return URL
  } else {
    print("❌ Upload failed with status: ${response.statusCode}");
    return null; // ✅ return null ถ้า error
  }
}
