import 'package:alkaram_hosiery/Auth/login.dart';
import 'package:alkaram_hosiery/Auth/register.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard.dart';
import 'firebase_options.dart';
import 'lanprovider.dart'; // Import your LanguageProvider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: languageProvider.isEnglish
                ? 'Al-Karam Hosiery Management'
                : 'الکرم ہوزیری مینجمنٹ',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              fontFamily: languageProvider.isEnglish ? null : 'JameelNoori', // Add Urdu font for Urdu text
            ),
            home:  LoginPage(),
          );
        },
      ),
    );
  }
}