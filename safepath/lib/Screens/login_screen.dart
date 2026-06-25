import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import 'package:Safepath/services/language_manager.dart';
import 'package:Safepath/services/language_string.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTtsAndWelcome();
  }

  Future<void> _initTtsAndWelcome() async {
    await _flutterTts.setLanguage(
      LanguageManager.isArabic ? "ar-SA" : "en-US",
    );

    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);

    // الحل الذكي: أول ما ينتهي نطق أي جملة، يتأكد ويشغل التعليمات
    _flutterTts.setCompletionHandler(() {
      // بنشيل الـ Handler بعد ما يشتغل أول مرة عشان ما يكررش التعليمات مع كل نطق تاني
      _flutterTts.setCompletionHandler(() {}); 
      _speakHelpInstructions();
    });

    // تأخير بسيط جداً لاستقرار الشاشة قبل بدء الترحيب
    await Future.delayed(const Duration(milliseconds: 400));
    
    // نطق رسالة الترحيب (التعليمات هتشتغل لوحدها فور انتهائها بفضل الـ CompletionHandler)
    await _flutterTts.speak(LanguageStrings.get("welcome"));
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _speakHelpInstructions() {
    _flutterTts.speak(
      LanguageManager.isArabic
          ? "طريقة استخدام التطبيق: يمكنك الضغط مطولا على الشاشة للحصول على التعليمات."
          : "How to use the application: Long press on the screen for help instructions.",
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("http://192.168.1.10:8000/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text,
          "password": passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        await _speak(LanguageStrings.get("loginSuccess"));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        final err = jsonDecode(response.body);
        String errorMsg = err["detail"] ?? LanguageStrings.get("loginFailed");

        await _speak(errorMsg);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      await _speak(LanguageStrings.get("connectionError"));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageStrings.get("connectionError"))),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () {
          _speakHelpInstructions();
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 9, 77, 132),
                Color(0xFF0D47A1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          /// Logo
                          Container(
                            width: 95,
                            height: 95,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "SafePath",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            LanguageStrings.get("login"),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 35),
                          
                          /// حقل الإيميل
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: LanguageStrings.get("email"), 
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF0D47A1),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          /// حقل الباسورد
                          TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: LanguageStrings.get("password"),
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF0D47A1),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF0D47A1),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      LanguageStrings.get("signIn"),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, "/signup");
                            },
                            child: Text(
                              LanguageStrings.get("createAccount"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}