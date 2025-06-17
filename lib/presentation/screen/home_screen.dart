import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras[0],
          ResolutionPreset.medium,
        );
        _initializeControllerFuture = _controller!.initialize();
        setState(() {
          _isCameraPermissionGranted = true;
        });
      }
    } else {
      setState(() {
        _isCameraPermissionGranted = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraPermissionGranted) {
      return const Center(child: Text('카메라 권한이 필요합니다.'));
    }
    if (_controller == null || _initializeControllerFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(_controller!);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
