import 'package:camera/camera.dart';
import 'package:driver_sleep_detection/screen/face_detection/controller/face_detection_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../face_detection_settings/advanced_settings_screen.dart'; // Import the settings page

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  final FaceDetectionScreenController _controller =
      Get.find<FaceDetectionScreenController>();

  Widget _buildCameraPreview() {
    return GetBuilder<FaceDetectionScreenController>(
      builder: (controller) {
        if (!controller.isCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.isExternalCamera) {
          return UVCCameraView(
            cameraController: controller.uvcCamera!,
            width: 300,
            height: 300,
          );
        } else {
          return CameraPreview(controller.cameraController!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Sleep Detection'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Top half: Camera view (Wrapped in Obx to reactively show the camera when initialized)
          Expanded(
            flex: 2,
            child: SizedBox(
              width: double.maxFinite,
              child: _buildCameraPreview(),
            ),
          ),
          // Bottom half: Status, Start/Stop button, settings, and PiP
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                // Status text at the top center (Wrapped in Obx to reactively show status)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Obx(() {
                    Logger().e(_controller.detectionStatus.value);
                    return Text(
                      'Status: ${_controller.detectionStatus.value}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                ),
                // Centered Start/Stop button (Wrapped in Obx to reactively toggle button text)
                Center(
                  child: GetBuilder<FaceDetectionScreenController>(
                    builder: (controller) {
                      return ElevatedButton(
                        onPressed: () {
                          if (_controller.isDetecting) {
                            _controller.stopDetection();
                          } else {
                            _controller.startDetection();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          foregroundColor: Colors.black,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(40),
                          elevation: 5,
                        ),
                        child: Text(
                          _controller.isDetecting ? 'Stop' : 'Start',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // PiP Icon button (left bottom corner)
                /*Positioned(
                  bottom: 20,
                  left: 20, // Symmetrical to the settings icon
                  child: IconButton(
                    onPressed: () {
                      // Handle PiP functionality here
                      Logger().i("PiP button clicked");
                    },
                    icon: const Icon(Icons.picture_in_picture_alt),
                    color: Colors.cyan,
                    iconSize: 50,
                  ),
                ),*/
                // Advanced Settings icon button in the bottom-right corner
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: IconButton(
                    onPressed: () {
                      Get.to(() => const AdvancedSettingsScreen());
                    },
                    icon: const Icon(Icons.settings),
                    color: Colors.cyan,
                    iconSize: 50,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
