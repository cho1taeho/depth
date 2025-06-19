import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:depth/presentation/state/depth_state.dart';

class HomeScreen extends StatelessWidget {
  final bool isCameraPermissionGranted;
  final CameraController? controller;
  final Future<void>? initializeControllerFuture;
  final DepthState state;
  final VoidCallback onTakePicture;

  const HomeScreen({
    Key? key,
    required this.isCameraPermissionGranted,
    required this.controller,
    required this.initializeControllerFuture,
    required this.state,
    required this.onTakePicture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isCameraPermissionGranted) {
      return const Center(child: Text('카메라 권한이 필요합니다.'));
    }
    if (controller == null || initializeControllerFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<void>(
      future: initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(
            children: [
              CameraPreview(controller!),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: state.isLoading ? null : onTakePicture,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ),
              if (state.filePath != null)
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('사진 저장 경로: ${state.filePath}'),
                  ),
                ),
              if (state.error != null)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '에러: ${state.error}',
                      style: const TextStyle(color: Colors.red),
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
}