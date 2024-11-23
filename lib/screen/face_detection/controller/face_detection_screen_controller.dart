import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceDetectionScreenController extends GetxController {
  CameraController? cameraController;
  RxBool isCameraInitialized = false.obs;
  bool isDetecting = false;
  bool alarmTriggered = false;

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Enables probability scores for eyes open/closed
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final audioPlayer = AudioPlayer();
  RxString detectionStatus = 'Not Detecting'.obs;

  bool isProcessingFrame = false;
  int frameCount = 0;
  final int frameSkip = 2; // Process every 3rd frame

  @override
  void onInit() {
    super.onInit();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      var cameraStatus = await Permission.camera.request();

      if (!cameraStatus.isGranted) {
        detectionStatus.value = 'Camera permission is required';
        update();
        return;
      }

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await cameraController?.initialize();
      isCameraInitialized.value = true;
      update();
    } catch (e) {
      detectionStatus.value = 'Camera initialization error: $e';
      update();
    }
  }

  void startDetection() {
    if (isDetecting) return;
    if (!isCameraInitialized.value) {
      detectionStatus.value = 'Camera not initialized';
      return;
    }

    isDetecting = true;
    detectionStatus.value = 'Detecting...';
    update();

    cameraController?.startImageStream((CameraImage image) async {
      frameCount++;
      if (frameCount % (frameSkip + 1) != 0) {
        return; // Skip frames to reduce processing load
      }

      if (isProcessingFrame) return;
      isProcessingFrame = true;

      try {
        await processImage(image);
      } catch (e) {
        detectionStatus.value = 'Processing error: $e';
      } finally {
        isProcessingFrame = false;
      }
    });
  }

  void stopDetection() {
    if (!isDetecting) return;
    isDetecting = false;
    detectionStatus.value = 'Detection stopped';
    cameraController?.stopImageStream();
    update();
    stopAlarm();
  }

  Future<void> processImage(CameraImage image) async {
    try {
      final inputImage = _convertCameraImageToInputImage(image);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
          final leftEyeOpen = face.leftEyeOpenProbability!;
          final rightEyeOpen = face.rightEyeOpenProbability!;
          if (leftEyeOpen < 0.3 && rightEyeOpen < 0.3) {
            detectionStatus.value = 'Sleep Detected!';
            triggerAlarm();
            return;
          } else {
            detectionStatus.value = 'Awake';
            stopAlarm();
          }
        }
      } else {
        detectionStatus.value = 'No Face Detected';
        stopAlarm();
      }
    } catch (e) {
      detectionStatus.value = 'Error: ${e.toString()}';
      stopAlarm();
    }
  }

  void triggerAlarm() {
    if (alarmTriggered) return;
    alarmTriggered = true;
    Logger().i("Alarm triggered!");
    audioPlayer.play(AssetSource('alarm.mp3')).catchError((error) {
      Logger().e("Error playing alarm: $error");
    });
  }

  void stopAlarm() {
    if (!alarmTriggered) return;
    alarmTriggered = false;
    Logger().i("Alarm stop!");
    audioPlayer.stop();
  }

  InputImage _convertCameraImageToInputImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final int bytesPerRow = image.planes[0].bytesPerRow;

    // Convert image format
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getImageRotation(),
        format: InputImageFormat.nv21,
        bytesPerRow: bytesPerRow, // Pass bytesPerRow here
      ),
    );
  }

  InputImageRotation _getImageRotation() {
    final int rotation = cameraController!.description.sensorOrientation;
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  void onClose() {
    stopDetection();
    cameraController?.dispose();
    faceDetector.close();
    audioPlayer.dispose();
    super.onClose();
  }
}
