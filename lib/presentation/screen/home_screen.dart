import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

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
          return Stack(
            children: [
              CameraPreview(_controller!),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _takePicture,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      // 저장 경로: 앱 전용 디렉토리
      final directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await image.saveTo(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진이 저장되었습니다!\n$filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 저장 실패: $e')),
        );
      }
    }
  }
}
