import 'package:camera/camera.dart';
import 'depth_data_source.dart';

class DepthDataSourceImpl implements DepthDataSource {
  @override
  Future<XFile> takePicture(CameraController controller) async {
    return await controller.takePicture();
  }
}