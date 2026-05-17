import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:Safepath/Screens/money_page.dart';
import 'camera_screen.dart';
import 'face_recognition_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';


class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  late List<Widget> screens;

  @override
  void initState() {
    super.initState();

    screens = [
      CameraScreen(cameras: widget.cameras),
      const MoneyPage(),
      FaceRecognitionScreen(cameras: widget.cameras),
      const HistoryScreen(),
      const SettingsScreen(),
      const UploadScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: const Color.fromARGB(224, 126, 126, 126),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: "Camera",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: "Money",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Person",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: "Upload",
          ),
        ],
      ),
    );
  }
}
