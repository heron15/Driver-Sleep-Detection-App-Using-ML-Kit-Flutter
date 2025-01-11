import 'dart:async'; // Import Timer class
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class FaceDetectionScreenController extends GetxController {
  CameraController? cameraController;
  bool isCameraInitialized = false;
  bool isDetecting = false;
  bool alarmTriggered = false;

  String defaultSound = 'alarm.mp3';
  RxInt detectionInterval = 1.obs; // Default to 1 minute
  Timer? _intervalTimer; // Timer for periodically triggering face detection

  bool isExternalCamera = false;
  UVCCameraController? uvcCamera;

  void setInterval(int minutes) {
    detectionInterval.value = minutes;
    // If detection is running, restart the interval timer
    if (isDetecting) {
      _startIntervalTimer();
    }
  }

  void _startIntervalTimer() {
    _intervalTimer?.cancel(); // Cancel any previous timer
    _intervalTimer =
        Timer.periodic(Duration(minutes: detectionInterval.value), (timer) {
      if (isDetecting) {
        Logger().i(
            'Triggering detection check after ${detectionInterval.value} minute(s)');
        detectionStatus.value = 'Checking for Sleep...';
        update();

        // Call face detection function periodically
        // Pass the actual CameraImage from the stream, not a new one
        // You might want to refactor how you handle the CameraImage here
      }
    });
  }

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification:
          true, // Enables probability scores for eyes open/closed
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final audioPlayer = AudioPlayer();
  RxString detectionStatus = 'Not Detecting'.obs;

  bool isProcessingFrame = false;
  int frameCount = 0;
  final int frameSkip = 2; // Process every 3rd frame

  int consecutiveSleepFrames = 0;
  static const int requiredSleepFrames =
      5; // Number of consecutive frames needed to confirm sleep

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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await cameraController?.initialize();
      isCameraInitialized = true;
      update();
    } catch (e) {
      Logger().e('Camera initialization error: $e');
      detectionStatus.value = 'Camera initialization error: $e';
      update();
    }
  }

  Future<void> switchToExternalCamera() async {
    try {
      stopDetection(); // Stop current detection

      // Dispose current camera if exists
      await cameraController?.dispose();
      cameraController = null;

      // Initialize UVC camera
      uvcCamera = UVCCameraController();

      // Add message callback for status updates
      uvcCamera?.msgCallback = (state) {
        Logger().i('UVC Camera state: $state');
        detectionStatus.value = state;
        update();
      };

      isExternalCamera = true;
      isCameraInitialized = true;
      update();
    } catch (e) {
      Logger().e('External camera error: $e');
      detectionStatus.value = 'External camera error: $e';
      await switchToInternalCamera(); // Fall back to internal camera
    }
  }

  Future<void> switchToInternalCamera() async {
    try {
      stopDetection(); // Stop current detection

      // Dispose USB camera if exists
      if (uvcCamera != null) {
        uvcCamera = null;
      }

      isExternalCamera = false;
      await initializeCamera(); // Initialize internal camera
    } catch (e) {
      Logger().e('Internal camera switch error: $e');
      detectionStatus.value = 'Camera switch error: $e';
    }
  }

  void startDetection() {
    if (isDetecting) return;
    if (!isCameraInitialized) {
      detectionStatus.value = 'Camera not initialized';
      return;
    }

    resetDetection();
    isDetecting = true;
    detectionStatus.value = 'Detecting...';
    update();

    if (isExternalCamera) {
      _startExternalCameraDetection();
    } else {
      _startInternalCameraDetection();
    }

    _startIntervalTimer();
  }

  void _startExternalCameraDetection() {
    if (uvcCamera == null) return;

    uvcCamera?.msgCallback = (String message) {
      if (!isDetecting) return;

      // Log camera status
      Logger().i('UVC Camera status: $message');

      if (message.contains('started')) {
        detectionStatus.value = 'External Camera Active';
      } else if (message.contains('stopped')) {
        detectionStatus.value = 'External Camera Stopped';
      } else if (message.contains('error')) {
        detectionStatus.value = 'External Camera Error';
        // Fallback to internal camera if there's an error
        switchToInternalCamera();
      }
    };
  }

  void _startInternalCameraDetection() {
    cameraController?.startImageStream((CameraImage image) async {
      frameCount++;
      if (frameCount % (frameSkip + 1) != 0) return;

      if (isProcessingFrame) return;
      isProcessingFrame = true;

      try {
        await processImage(image);
      } catch (e) {
        Logger().e('Stream processing error: $e');
        detectionStatus.value = 'Processing error: $e';
      } finally {
        isProcessingFrame = false;
      }
    });
  }

  Future<void> _processFaceDetection(InputImage inputImage) async {
    try {
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        if (face.leftEyeOpenProbability != null &&
            face.rightEyeOpenProbability != null) {
          final leftEyeOpen = face.leftEyeOpenProbability!;
          final rightEyeOpen = face.rightEyeOpenProbability!;

          final avgEyeOpenness = (leftEyeOpen + rightEyeOpen) / 2;
          Logger().d(
              'Left eye: $leftEyeOpen, Right eye: $rightEyeOpen, Avg: $avgEyeOpenness');

          if (avgEyeOpenness < 0.3) {
            consecutiveSleepFrames++;
            detectionStatus.value =
                'Possible Sleep Detected ($consecutiveSleepFrames/$requiredSleepFrames)';

            if (consecutiveSleepFrames >= requiredSleepFrames) {
              detectionStatus.value = 'Sleep Detected!';
              triggerAlarm();
            }
          } else {
            consecutiveSleepFrames = 0;
            detectionStatus.value = 'Awake';
            stopAlarm();
          }
        }
      } else {
        consecutiveSleepFrames = 0;
        detectionStatus.value = 'No Face Detected';
        stopAlarm();
      }
    } catch (e) {
      Logger().e('Face detection error: $e');
      detectionStatus.value = 'Error: ${e.toString()}';
      stopAlarm();
    }
  }

  void stopDetection() {
    if (!isDetecting) return;
    isDetecting = false;
    detectionStatus.value = 'Detection stopped';

    if (isExternalCamera) {
      // Just update the status for external camera
      detectionStatus.value = 'External Camera Stopped';
    } else {
      cameraController?.stopImageStream();
    }

    update();
    stopAlarm();
    _intervalTimer?.cancel();
  }

  Future<void> processImage(CameraImage image) async {
    try {
      final inputImage = _convertCameraImageToInputImage(image);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        if (face.leftEyeOpenProbability != null &&
            face.rightEyeOpenProbability != null) {
          final leftEyeOpen = face.leftEyeOpenProbability!;
          final rightEyeOpen = face.rightEyeOpenProbability!;

          // Calculate average eye openness
          final avgEyeOpenness = (leftEyeOpen + rightEyeOpen) / 2;

          // Log eye probabilities for debugging
          Logger().d(
              'Left eye: $leftEyeOpen, Right eye: $rightEyeOpen, Avg: $avgEyeOpenness');

          if (avgEyeOpenness < 0.3) {
            consecutiveSleepFrames++;
            detectionStatus.value =
                'Possible Sleep Detected ($consecutiveSleepFrames/$requiredSleepFrames)';

            if (consecutiveSleepFrames >= requiredSleepFrames) {
              detectionStatus.value = 'Sleep Detected!';
              triggerAlarm();
            }
          } else {
            consecutiveSleepFrames = 0;
            detectionStatus.value = 'Awake';
            stopAlarm();
          }
        }
      } else {
        consecutiveSleepFrames = 0;
        detectionStatus.value = 'No Face Detected';
        stopAlarm();
      }
    } catch (e) {
      Logger().e('Processing error: $e');
      detectionStatus.value = 'Error: ${e.toString()}';
      stopAlarm();
    }
  }

  void triggerAlarm() {
    if (alarmTriggered) return; // Avoid multiple alarms
    alarmTriggered = true;
    Logger().i("Sleep detected! Alarm will sound in 3 seconds.");

    // Start a 3-second timer before triggering the alarm sound
    Timer(const Duration(seconds: 3), () {
      if (alarmTriggered) {
        // Check if the alarm is still valid
        Logger().i("Alarm triggered after 3 seconds!");
        audioPlayer.play(AssetSource(defaultSound)).catchError((error) {
          Logger().e("Error playing alarm: $error");
        });
      }
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

    // Check the format and convert accordingly
    if (Platform.isAndroid) {
      // For Android, we need to convert YUV to NV21
      Uint8List? nv21Buffer = _convertYUV420ToNV21(image);
      if (nv21Buffer != null) {
        allBytes.putUint8List(nv21Buffer);
      }
    } else {
      // For iOS, use the original format
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _getImageRotation(),
      format: Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }

  // Add this method to convert YUV420 to NV21
  Uint8List? _convertYUV420ToNV21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;

      final int size = width * height;
      final int quarter = size ~/ 4;
      final Uint8List nv21 = Uint8List(size + (size ~/ 2));

      // Copy Y channel
      var yBuffer = image.planes[0].bytes;
      if (image.planes[0].bytesPerRow == width) {
        // If stride equals width, we can copy whole plane at once
        nv21.setRange(0, size, yBuffer);
      } else {
        // Copy row by row
        int rowStride = image.planes[0].bytesPerRow;
        for (int y = 0; y < height; y++) {
          int inputOffset = y * rowStride;
          int outputOffset = y * width;
          nv21.setRange(outputOffset, outputOffset + width,
              yBuffer.sublist(inputOffset, inputOffset + width));
        }
      }

      // Copy VU data
      int uvIndex = size;
      int u = 0;
      int v = 0;
      int index = 0;

      for (int y = 0; y < height ~/ 2; y++) {
        for (int x = 0; x < width ~/ 2; x++) {
          index = uvRowStride * y + x * uvPixelStride;

          v = image.planes[1].bytes[index];
          u = image.planes[2].bytes[index];

          nv21[uvIndex++] = v;
          nv21[uvIndex++] = u;
        }
      }

      return nv21;
    } catch (e) {
      Logger().e('Error converting YUV420 to NV21: $e');
      return null;
    }
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

  void resetDetection() {
    consecutiveSleepFrames = 0;
    stopAlarm();
    detectionStatus.value = 'Detection Reset';
    update();
  }

  @override
  void onClose() {
    stopDetection();
    cameraController?.dispose();
    uvcCamera = null;
    faceDetector.close();
    audioPlayer.dispose();
    super.onClose();
  }
}
