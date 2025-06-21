import 'package:camera/camera.dart';

abstract class DepthRepository {
  Future<XFile> takePicture(CameraController controller);
}