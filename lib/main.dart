import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:test_databse/firebase_options.dart';
import 'package:test_databse/screens/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:test_databse/screens/upload_area.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginPage(),
      routes: {"/upload": (context) => UploadArea()},
    );
  }
}
// class CheckUser extends StatefulWidget {
//   const CheckUser({super.key});

//   @override
//   State<CheckUser> createState() => _CheckUserState();
// }

// class _CheckUserState extends State<CheckUser> {
//   @override
//   void initState( ) {
// LoginController().isLoggedIn().then(
//   (value){
//     // if(value){
//     //   Navigator.push(context, );
//     // }
//   }
// );
//     super.setState();
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(body: Center(child: CircularProgressIndicator()),);
//  }
// }
