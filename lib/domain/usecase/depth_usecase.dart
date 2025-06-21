import 'package:camera/camera.dart';
import 'package:depth/data/repository/depth_repository.dart';


class DepthUseCase {
  final DepthRepository repository;

  DepthUseCase(this.repository);

  Future<XFile> takePicture(CameraController controller) async {
    return await repository.takePicture(controller);
  }
}