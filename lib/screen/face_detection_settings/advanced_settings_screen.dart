import 'package:driver_sleep_detection/screen/face_detection/controller/face_detection_screen_controller.dart';
import 'package:driver_sleep_detection/screen/face_detection_settings/controller/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  bool _isDarkMode = false; // Track theme mode (false = Light, true = Dark)
  double _currentVolume = 0; // Initial volume value

  @override
  void initState() {
    super.initState();
    // Fetch current volume during initialization
    FlutterVolumeController.getVolume().then((volume) {
      setState(() {
        _currentVolume = (volume ?? 0.0) * 100; // Convert 0-1 range to 0-100
      });
    });

    // Listen to system volume changes
    FlutterVolumeController.addListener((volume) {
      setState(() {
        _currentVolume = volume * 100; // Convert 0-1 range to 0-100
      });
    });
  }

  // Dispose the listener we have created
  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: AnimatedTheme(
        data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
        duration: const Duration(milliseconds: 300),
        child: Scaffold(
          appBar: _appBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMinimalRoundedButton(
                    'Use External Camera',
                    _handleExternalCamera,
                  ),
                  const SizedBox(height: 16),
                  _buildMinimalRoundedButton(
                    'Use Internal Camera',
                    _handleInternalCamera,
                  ),
                  const SizedBox(height: 16),
                  _buildMinimalRoundedButton('Use Interval Mode', () {
                    _showIntervalOptions(context);
                  }),
                  const SizedBox(height: 16),
                  _buildMinimalRoundedButton('Change Audio', () {
                    _showAudioOptions(context);
                  }),
                  const SizedBox(height: 24),
                  _volumePart(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _volumePart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Volume',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildProgressBarSlider(),
        const SizedBox(height: 10),
        Text(
          '${_currentVolume.toInt()}%',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  AppBar _appBar() {
    return AppBar(
      title: Text(
        'Advanced Settings',
        style: TextStyle(
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      backgroundColor: Colors.cyan,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            _isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            setState(() {
              _isDarkMode = !_isDarkMode;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMinimalRoundedButton(String title, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 15),
        minimumSize: const Size(250, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildProgressBarSlider() {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Full grey track (background)
        Container(
          height: 20, // Thickness of the progress bar
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade300, // Empty track color
          ),
        ),
        // Filled gradient based on the current volume
        FractionallySizedBox(
          widthFactor: _currentVolume / 100, // Dynamically scale width
          child: Container(
            height: 20, // Thickness of the progress bar
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.cyan, // Gradient color for the track
                  Colors.cyan,
                ],
              ),
            ),
          ),
        ),
        // Circular thumb overlay for interaction
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 16, // Larger thumb size
            ),
            thumbColor: Colors.white, // Thumb color
            overlayColor: Colors.white.withOpacity(0.4), // Subtle glow effect
            trackHeight: 0, // Hide default track
          ),
          child: Slider(
            value: _currentVolume,
            min: 0,
            max: 100, // Set the max value to 100
            onChanged: (value) {
              setState(() {
                _currentVolume = value; // Update the slider value
              });
              FlutterVolumeController.setVolume(
                  value / 100); // Convert to 0-1 for FlutterVolumeController
            },
          ),
        ),
      ],
    );
  }

  void _showIntervalOptions(BuildContext context) {
    _showCustomPopup(
      context,
      title: 'Select Interval Time',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleButton('1 Min', () => _setInterval(1)),
          _buildCircleButton('2 Min', () => _setInterval(2)),
          _buildCircleButton('3 Min', () => _setInterval(3)),
          _buildCircleButton('5 Min', () => _setInterval(5)),
        ],
      ),
    );
  }

  void _setInterval(int minutes) {
    // Assuming _controller is your FaceDetectionScreenController instance
    Get.find<FaceDetectionScreenController>()
        .setInterval(minutes); // Call setInterval on the controller
    Navigator.pop(context); // Close the interval options popup
  }

  void _showAudioOptions(BuildContext context) {
    _showCustomPopup(
      context,
      title: 'Select Audio',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildAudioOptions([
          'sound1.mp3',
          'sound2.mp3',
          'sound3.mp3',
          'sound4.mp3',
          'sound5.mp3'
        ]),
      ),
    );
  }

  void _showCustomPopup(BuildContext context,
      {required String title, required Widget child}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, animation1, animation2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[900] : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation1, animation2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation1),
          child: FadeTransition(
            opacity: animation1,
            child: child,
          ),
        );
      },
      transitionDuration:
          const Duration(milliseconds: 300), // Popup transition duration
    );
  }

  List<Widget> _buildAudioOptions(List<String> options) {
    return options.map((option) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: GetBuilder<SettingsController>(builder: (controller) {
          return ElevatedButton(
            onPressed: () {
              controller.changeSound(option);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Get.find<FaceDetectionScreenController>().defaultSound ==
                          option
                      ? Colors.cyan
                      : Colors.grey.shade700,
              foregroundColor: _isDarkMode ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              minimumSize: const Size(250, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          );
        }),
      );
    }).toList();
  }

  Widget _buildCircleButton(String title, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  void _handleExternalCamera() async {
    final controller = Get.find<FaceDetectionScreenController>();
    await controller.switchToExternalCamera();
    Get.back(); // Return to face detection screen
  }

  void _handleInternalCamera() async {
    final controller = Get.find<FaceDetectionScreenController>();
    await controller.switchToInternalCamera();
    Get.back(); // Return to face detection screen
  }
}
