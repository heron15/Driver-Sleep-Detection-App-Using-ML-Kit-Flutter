import 'package:driver_sleep_detection/dependency.dart';
import 'package:driver_sleep_detection/screen/face_detection/face_detection_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home:  FaceDetectionScreen(),
      initialBinding: Dependency(),
    );
  }
}
