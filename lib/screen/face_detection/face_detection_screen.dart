
import 'package:camera/camera.dart';
import 'package:driver_sleep_detection/screen/face_detection/controller/face_detection_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  final FaceDetectionScreenController _controller = Get.find<FaceDetectionScreenController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Sleep Detection'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Top half: Camera view
          Expanded(
            flex: 2,
            child: Obx(() {
              if (_controller.isCameraInitialized.value) {
                return SizedBox(
                  width: double.maxFinite,
                  child: CameraPreview(_controller.cameraController!),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }),
          ),
          // Bottom half: Start/Stop button and status
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () {
                    Logger().e(_controller.detectionStatus.value);
                    return Text(
                      'Status: ${_controller.detectionStatus.value}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 20),
                GetBuilder<FaceDetectionScreenController>(
                  builder: (controller) {
                    return ElevatedButton(
                      onPressed: () {
                        if (controller.isDetecting) {
                          controller.stopDetection();
                        } else {
                          controller.startDetection();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15,horizontal: 13),
                        shape:RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        )
                      ),
                      child: Text(controller.isDetecting ? 'Stop' : 'Start Detection'),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
