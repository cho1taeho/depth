import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:depth/core/provider/provider.dart';
import 'home_screen.dart';

class HomeScreenRoot extends ConsumerStatefulWidget {
  const HomeScreenRoot({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreenRoot> createState() => _HomeScreenRootState();
}

class _HomeScreenRootState extends ConsumerState<HomeScreenRoot> {
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
    final viewModel = ref.watch(depthViewModelProvider);

    return HomeScreen(
      isCameraPermissionGranted: _isCameraPermissionGranted,
      controller: _controller,
      initializeControllerFuture: _initializeControllerFuture,
      state: viewModel.state,
      onTakePicture: () => viewModel.takeDepthPicture(_controller),
    );
  }
}