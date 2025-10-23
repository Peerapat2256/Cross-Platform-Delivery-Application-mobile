import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_databse/controller/%E0%B8%B5user_regis_controller.dart';
import 'package:test_databse/model/profile.dart';
import 'package:test_databse/screens/login_screen.dart';
import 'package:test_databse/service/clouddinary_service.dart';

class UserRegisterPage extends StatefulWidget {
  const UserRegisterPage({super.key, required UserType userType});

  @override
  State<UserRegisterPage> createState() => _UserRegisterPageState();
}

class _UserRegisterPageState extends State<UserRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _registerController = UserRegisController();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  File? selectedImage;
  bool _isPressedRider = false;
  bool _isUploading = false; // Loading state

  Widget _buildButton({
    required String text,
    required IconData icon,
    required Color color,
    required Color textColor,
    required bool isPressed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressedRider = true),
      onTapUp: (_) {
        setState(() => _isPressedRider = false);
        Future.delayed(const Duration(milliseconds: 150), onTap);
      },
      onTapCancel: () => setState(() => _isPressedRider = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.17),
                    offset: const Offset(1, 10),
                    blurRadius: 6,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(icon, color: textColor),
            const SizedBox(width: 8),
            Text(
              _isUploading ? "กำลังสมัคร..." : text,
              style: GoogleFonts.prompt(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      allowedExtensions: ["jpg", "jpeg", "png"],
      type: FileType.custom,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);

      try {
        String? imageUrl;

        if (selectedImage != null) {
          final tempResult = FilePickerResult([
            PlatformFile(
              name: selectedImage!.path.split('/').last,
              path: selectedImage!.path,
              size: selectedImage!.lengthSync(),
            ),
          ]);
          imageUrl = await uploadTocloud(tempResult);
          if (imageUrl == null) throw Exception("Failed to upload image");
        }

        await _registerController.register(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
          imageUrl: imageUrl, // ส่ง URL จาก Cloudinary ไปตรงนี้
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("สมัครสมาชิกเรียบร้อย ✅")));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  Text(
                    "สมัครสมาชิก",
                    style: GoogleFonts.prompt(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "ผู้ใช้",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.prompt(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: selectedImage != null
                              ? FileImage(selectedImage!)
                              : null,
                          child: selectedImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 45,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_a_photo),
                          onPressed: _openFilePicker,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: nameController,
                    validator: RequiredValidator(errorText: "กรุณากรอกชื่อ"),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.person),
                      labelText: 'Name',
                      hintText: 'Your Name, e.g. John Doe',
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: MultiValidator([
                      RequiredValidator(errorText: "กรุณาป้อนอีเมล"),
                      EmailValidator(errorText: "รูปแบบอีเมลไม่ถูกต้อง"),
                    ]),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.email),
                      labelText: 'Email',
                      hintText: 'example@gmail.com',
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    validator: RequiredValidator(
                      errorText: "กรุณากรอกเบอร์โทร",
                    ),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.phone),
                      labelText: 'Phone Number',
                      hintText: 'e.g. 081-234-5678',
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    validator: MinLengthValidator(
                      8,
                      errorText: "รหัสผ่านต้องอย่างน้อย 8 ตัว",
                    ),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.lock),
                      labelText: 'Password',
                      hintText: 'At least 8 characters',
                    ),
                  ),
                  const SizedBox(height: 50),
                  _buildButton(
                    text: "สมัครสมาชิก",
                    icon: Icons.delivery_dining,
                    color: Colors.green.shade700,
                    textColor: Colors.white,
                    isPressed: _isPressedRider,
                    onTap: _isUploading ? () {} : _submitForm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
