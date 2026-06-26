import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:Safepath/services/tts_manager.dart';
import 'package:Safepath/services/language_manager.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final TtsManager ttsManager = TtsManager();

  @override
  void initState() {
    super.initState();
    speakWelcome();
  }

  Future<void> speakWelcome() async {
    await Future.delayed(const Duration(milliseconds: 700));
    await ttsManager.setLanguage("en-US");
    await ttsManager.speakAndWait(
      "Please choose your preferred language to continue.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF030A16), Color(0xFF0A1E3D), Color(0xFF0D2B5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 35,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A56DB).withOpacity(0.2),
                            border: Border.all(
                              color: const Color(0xFF60A5FA).withOpacity(0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            size: 32,
                            color: Color(0xFF93C5FD),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "SafePath",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 30),

                        LanguageButton(
                          flag: "🇪🇬",
                          title: "العربية",
                          subtitle: "Arabic",
                          onTap: () async {
                            await LanguageManager.saveLanguage("ar");
                            await ttsManager.setLanguage("ar-SA");
                            await ttsManager.speakAndWait(
                              "تم اختيار اللغة العربية",
                            );
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );

                            if (!mounted) return;
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                        ),
                        const SizedBox(height: 16),

                        LanguageButton(
                          flag: "🇺🇸",
                          title: "English",
                          subtitle: "English",
                          onTap: () async {
                            await LanguageManager.saveLanguage("en");
                            await ttsManager.setLanguage("en-US");
                            await ttsManager.speakAndWait("English selected");
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );

                            if (!mounted) return;
                            Navigator.pushReplacementNamed(context, '/login');
                          },
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

class LanguageButton extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const LanguageButton({
    super.key,
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "$title language button",
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: const Color(0xFF3B82F6).withOpacity(0.2),
            highlightColor: const Color(0xFF3B82F6).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(flag, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.4),
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
