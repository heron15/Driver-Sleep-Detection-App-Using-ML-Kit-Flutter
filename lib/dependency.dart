import 'package:driver_sleep_detection/screen/face_detection/controller/face_detection_screen_controller.dart';
import 'package:get/get.dart';

class Dependency extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FaceDetectionScreenController(), fenix: true);
  }
}