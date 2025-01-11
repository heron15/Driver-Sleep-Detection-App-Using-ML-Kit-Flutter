import 'package:driver_sleep_detection/screen/face_detection/controller/face_detection_screen_controller.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  void changeSound(String newSound) {
    // Change the default sound in the face detection controller
    Get.find<FaceDetectionScreenController>().defaultSound = newSound;
    update();  // Notify the UI to update if necessary
  }
}