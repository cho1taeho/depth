import 'package:camera/camera.dart';

abstract interface class DepthDataSource {
  Future<XFile> takePicture(CameraController controller);
}