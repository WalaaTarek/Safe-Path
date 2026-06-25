import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:Safepath/services/language_manager.dart';
import 'package:Safepath/services/language_string.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("http://192.168.1.10:8000/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": nameController.text,
          "email": emailController.text,
          "password": passwordController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageStrings.get("signupSuccess")),
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          "/login",
        );
      } else {
        final err = jsonDecode(response.body);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err["detail"] ?? LanguageStrings.get("loginFailed"),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageStrings.get("connectionError")),
        ),
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
      body: Container(
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
                  filter: ImageFilter.blur(
                    sigmaX: 15,
                    sigmaY: 15,
                  ),
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
                              colors: [
                                Color(0xFF42A5F5),
                                Color(0xFF1565C0),
                              ],
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
                          LanguageStrings.get("signup"),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 35),

                        /// 1) حقل الاسم الكامل بعد تعديل الـ hintText
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: LanguageManager.isArabic
                                ? "الاسم الكامل"
                                : "Full Name",
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.person_outline,
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

                        /// 2) حقل البريد الإلكتروني بعد تعديل الـ hintText
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

                        /// 3) حقل كلمة المرور بعد تعديل الـ hintText
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
                            onPressed: _isLoading ? null : signup,
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
                                    LanguageStrings.get("createAccount"),
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
                            Navigator.pushReplacementNamed(
                              context,
                              "/login",
                            );
                          },
                          child: Text(
                            LanguageStrings.get("signIn"),
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
    );
  }
}