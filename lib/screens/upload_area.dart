import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:test_databse/service/clouddinary_service.dart';

class UploadArea extends StatefulWidget {
  const UploadArea({super.key});

  @override
  State<UploadArea> createState() => _UploadAreaState();
}

class _UploadAreaState extends State<UploadArea> {
  String? uploadedUrl;

  @override
  Widget build(BuildContext context) {
    final selectedFile =
        ModalRoute.of(context)!.settings.arguments as FilePickerResult;

    return Scaffold(
      appBar: AppBar(title: Text("Upload")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextFormField(
              readOnly: true,
              initialValue: selectedFile.files.first.name,
              decoration: InputDecoration(label: Text("Name")),
            ),
            TextFormField(
              readOnly: true,
              initialValue: selectedFile.files.first.extension,
              decoration: InputDecoration(label: Text("Extension")),
            ),
            TextFormField(
              readOnly: true,
              initialValue: "${selectedFile.files.first.size} bytes",
              decoration: InputDecoration(label: Text("Size")),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final url = await uploadTocloud(
                      selectedFile,
                    ); // ✅ return String?

                    if (url != null) {
                      setState(() {
                        uploadedUrl = url;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("File uploaded successfully")),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("File upload failed")),
                      );
                    }
                  },
                  child: Text("Upload"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (uploadedUrl != null) ...[
              SelectableText("URL: $uploadedUrl"),
              const SizedBox(height: 10),
              Image.network(uploadedUrl!, height: 200),
            ],
          ],
        ),
      ),
    );
  }
}
