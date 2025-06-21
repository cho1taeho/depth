import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class CameraTab extends ConsumerStatefulWidget {
  const CameraTab({Key? key}) : super(key: key);

  @override
  ConsumerState<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends ConsumerState<CameraTab> {
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

  Future<void> _takePicture() async {
    try {
      if (_controller == null) return;

      // ARCore를 통한 사진 촬영 (컬러 + Depth Map)
      // MethodChannel로 네이티브 호출
      const platform = MethodChannel('com.example.depth');
      final result = await platform.invokeMethod<Map<String, dynamic>>('captureImage');

      if (result != null) {
        final colorPath = result['colorPath'] as String?;
        final depthPath = result['depthPath'] as String?;

        // 갤러리에 저장 (컬러 이미지만)
        if (colorPath != null) {
          await _saveToGallery(colorPath);
        }
      }
    } catch (e) {
      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 촬영에 실패했습니다: $e')),
      );
    }
  }

  // 갤러리에 저장하는 함수
  Future<void> _saveToGallery(String imagePath) async {
    try {
      const platform = MethodChannel('com.example.depth');
      final result = await platform.invokeMethod<String>('saveToGallery', {
        'imagePath': imagePath,
      });

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 갤러리에 저장되었습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('갤러리 저장 중 오류가 발생했습니다: $e')),
      );
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('카메라 권한이 필요합니다.'),
          ],
        ),
      );
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
              // 카메라 프리뷰
              CameraPreview(_controller!),

              // 사진 촬영 버튼
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _takePicture,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.camera_alt, color: Colors.black),
                  ),
                ),
              ),

              // 상단 안내 텍스트
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '사진을 찍어서 거리 측정을 시작하세요',
                      style: TextStyle(color: Colors.white),
                    ),
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