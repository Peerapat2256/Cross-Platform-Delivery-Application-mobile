import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_databse/controller/rider_register_controller.dart';
import 'package:test_databse/model/profile.dart';
import 'package:test_databse/screens/login_screen.dart';
import 'package:test_databse/service/clouddinary_service.dart';

class RiderRegisterPage extends StatefulWidget {
  final UserType? userType;
  const RiderRegisterPage({super.key, this.userType});

  @override
  State<RiderRegisterPage> createState() => _RiderRegisterPageState();
}

class _RiderRegisterPageState extends State<RiderRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _registerController = RiderRegisterController();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController plateController = TextEditingController();

  File? selectedProfileImage;
  File? selectedPlateImage;
  bool _isPressedRider = false;
  bool _isUploading = false;

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
                    color: Colors.black.withOpacity(0.20),
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

  Future<void> _pickImage({required bool isProfile}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      allowedExtensions: ["jpg", "jpeg", "png"],
      type: FileType.custom,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isProfile) {
          selectedProfileImage = File(result.files.single.path!);
        } else {
          selectedPlateImage = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);

      try {
        String? profileImageUrl;
        String? plateImageUrl;

        // Upload profile image
        if (selectedProfileImage != null) {
          final tempResultprofile = FilePickerResult([
            PlatformFile(
              name: selectedProfileImage!.path.split('/').last,
              path: selectedProfileImage!.path,
              size: selectedProfileImage!.lengthSync(),
            ),
          ]);
          profileImageUrl = await uploadTocloud(tempResultprofile);
          if (profileImageUrl == null)
            throw Exception("Failed to upload profile image");
        }

        // Upload plate image
        if (selectedPlateImage != null) {
          final tempResultplate = FilePickerResult([
            PlatformFile(
              name: selectedPlateImage!.path.split('/').last,
              path: selectedPlateImage!.path,
              size: selectedPlateImage!.lengthSync(),
            ),
          ]);
          plateImageUrl = await uploadTocloud(tempResultplate);
          if (plateImageUrl == null)
            throw Exception("Failed to upload plate image");
        }

        await _registerController.register(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
          plate: plateController.text.trim(),
          imageUrl: profileImageUrl,
          plateUrl: plateImageUrl,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("สมัครสมาชิกเรียบร้อย ✅")));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
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
                    "ไรเดอร์",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.prompt(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // รูปโปรไฟล์
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: selectedProfileImage != null
                              ? FileImage(selectedProfileImage!)
                              : null,
                          child: selectedProfileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 45,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_a_photo),
                          onPressed: () => _pickImage(isProfile: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ชื่อ อีเมล เบอร์ รหัสผ่าน
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
                  const SizedBox(height: 40),

                  // เลขทะเบียนรถ
                  TextFormField(
                    controller: plateController,
                    keyboardType: TextInputType.text,
                    validator: MultiValidator([
                      RequiredValidator(errorText: "กรุณากรอกทะเบียนรถ"),
                      MinLengthValidator(5, errorText: "อย่างน้อย 5 ตัวอักษร"),
                      MaxLengthValidator(8, errorText: "ไม่เกิน 8 ตัวอักษร"),
                    ]),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.directions_car),
                      labelText: 'ทะเบียนรถ',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // รูปทะเบียนรถ
                  Text(
                    "รูปภาพยานพาหนะ",
                    style: GoogleFonts.prompt(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _pickImage(isProfile: false),
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: selectedPlateImage != null
                          ? Image.file(selectedPlateImage!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 30,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'แตะเพื่อเพิ่มรูปทะเบียนรถ',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ปุ่มสมัคร
                  _buildButton(
                    text: "สมัครสมาชิก",
                    icon: Icons.delivery_dining,
                    color: Colors.green.shade700,
                    textColor: Colors.white,
                    isPressed: _isPressedRider,
                    onTap: _isUploading ? () {} : _submitForm,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
