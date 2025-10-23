import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_databse/controller/login_controller.dart';
import 'package:test_databse/model/profile.dart';
import 'package:test_databse/screens/rider/rider_screen.dart';
import 'package:test_databse/screens/select_register_screen.dart';
import 'package:test_databse/screens/user_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPressedRider = false;

  String? _passwordComplex(String? value) {
    if (value == null || value.isEmpty) return "กรุณาป้อนรหัสผ่าน";
    if (value.length < 8) return "รหัสผ่านต้องอย่างน้อย 8 ตัวอักษร";

    return null;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final controller = LoginController();
      final profile = await controller.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (profile != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("เข้าสู่ระบบสำเร็จ")));

        if (profile.userType == UserType.user) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => UserHomePage()),
          );
        } else if (profile.userType == UserType.rider) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RiderHomePage()),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("ไม่พบประเภทผู้ใช้")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("อีเมลหรือรหัสผ่านไม่ถูกต้อง")),
        );
      }
    }
  }

  Widget _buildButton({
    required String text,
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
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.prompt(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
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
                    "เข้าสู่ระบบ",
                    style: GoogleFonts.prompt(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ===== Email =====
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: MultiValidator([
                      RequiredValidator(errorText: "กรุณาป้อนอีเมล"),
                      EmailValidator(errorText: "รูปแบบอีเมลไม่ถูกต้อง"),
                    ]),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.email),
                      labelText: 'อีเมล',
                      hintText: 'example@gmail.com',
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ===== Password =====
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    validator: _passwordComplex,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.lock),
                      labelText: 'รหัสผ่าน',
                      hintText: 'อย่างน้อย 8 ตัว และมีตัวเลข+ตัวอักษร',
                    ),
                  ),
                  const SizedBox(height: 50),

                  _buildButton(
                    text: "เข้าสู่ระบบ",
                    color: Colors.green.shade700,
                    textColor: Colors.white,
                    isPressed: _isPressedRider,
                    onTap: _submitForm,
                  ),
                  const SizedBox(height: 30),

                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => RegisterTypePage()),
                        );
                      },
                      child: const Text("สมัครสมาชิก"),
                    ),
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
