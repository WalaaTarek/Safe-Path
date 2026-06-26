import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:Safepath/services/tts_manager.dart';
import 'package:Safepath/services/language_manager.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLanguageChanged;

  const SettingsScreen({super.key, this.onLanguageChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsManager _ttsManager = TtsManager();
  String _currentLang = "en";

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    try {
      String savedLang = await LanguageManager.getLanguage();
      if (mounted) {
        setState(() {
          _currentLang = savedLang;
        });
      }
    } catch (e) {
      debugPrint("Error loading language: $e");
    }
  }

  Future<void> _changeLanguage(String langCode) async {
    if (_currentLang == langCode) return;

    setState(() {
      _currentLang = langCode;
    });

    await LanguageManager.saveLanguage(langCode);

    if (langCode == "ar") {
      await _ttsManager.setLanguage("ar-SA");
      await _ttsManager.speakAndWait("تم تغيير اللغة إلى العربية");
    } else {
      await _ttsManager.setLanguage("en-US");
      await _ttsManager.speakAndWait("Language changed to English");
    }

    if (widget.onLanguageChanged != null) {
      widget.onLanguageChanged!();
    }
  }

  Widget _sectionLabel(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0D47A1).withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: const Color(0xFF0D47A1).withOpacity(0.12),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.language_rounded, size: 16, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D47A1),
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bool isAr = _currentLang == "ar";

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AppBar(
                  title: Text(
                    isAr ? "الإعدادات" : "Settings",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: const Color(0xFF0F172A),
                      fontFamily: isAr ? 'Cairo' : null,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  children: [
                    Align(
                      alignment: isAr
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: _sectionLabel(
                        isAr ? "إعدادات اللغة" : "Language Settings",
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D47A1).withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                radioTheme: RadioThemeData(
                                  fillColor:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return const Color(0xFF0D47A1);
                                        }
                                        return Colors.black26;
                                      }),
                                ),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    value: "ar",
                                    groupValue: _currentLang,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    title: const Text(
                                      "العربية",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    secondary: const Text(
                                      "🇪🇬",
                                      style: TextStyle(fontSize: 22),
                                    ),
                                    onChanged: (value) {
                                      if (value != null) _changeLanguage(value);
                                    },
                                  ),
                                  Divider(
                                    height: 1,
                                    color: const Color(
                                      0xFF0D47A1,
                                    ).withOpacity(0.08),
                                    indent: isAr ? 16 : 64,
                                    endIndent: isAr ? 64 : 16,
                                  ),
                                  RadioListTile<String>(
                                    value: "en",
                                    groupValue: _currentLang,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    title: const Text(
                                      "English",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    secondary: const Text(
                                      "🇺🇸",
                                      style: TextStyle(fontSize: 22),
                                    ),
                                    onChanged: (value) {
                                      if (value != null) _changeLanguage(value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
