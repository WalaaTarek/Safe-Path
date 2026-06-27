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
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 9, 77, 132), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 15,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            size: 40,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      "اختر لغتك",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Choose your language",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 35),

                    LanguageButton(
                      flag: "🇪🇬",
                      title: "العربية",
                      subtitle: "Arabic",
                      gradientColors: const [Colors.white, Colors.white],
                      textColor: const Color(0xFF0D47A1),
                      hasShadow: true,
                      onTap: () async {
                        await LanguageManager.saveLanguage("ar");
                        await ttsManager.setLanguage("ar-SA");

                        await ttsManager.speakAndWait(
                          "تم اختيار اللغة العربية",
                        );

                        await Future.delayed(const Duration(milliseconds: 300));

                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),

                    const SizedBox(height: 14),

                    LanguageButton(
                      flag: "🇺🇸",
                      title: "English",
                      subtitle: "English",
                      gradientColors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.2),
                      ],
                      textColor: Colors.white,
                      hasShadow: false,
                      onTap: () async {
                        await LanguageManager.saveLanguage("en");
                        await ttsManager.setLanguage("en-US");

                        await ttsManager.speakAndWait("English selected");

                        await Future.delayed(const Duration(milliseconds: 300));

                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
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
  final List<Color> gradientColors;
  final Color textColor;
  final bool hasShadow;
  final VoidCallback onTap;

  const LanguageButton({
    super.key,
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.textColor,
    required this.hasShadow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "$title language button",
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(flag, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    height: 32,
                    width: 1,
                    color: textColor.withOpacity(0.15),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
