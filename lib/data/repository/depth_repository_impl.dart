import 'package:camera/camera.dart';
import '../datasource/depth_data_source.dart';
import 'depth_repository.dart';

class DepthRepositoryImpl implements DepthRepository {
  final DepthDataSource dataSource;

  DepthRepositoryImpl(this.dataSource);

  @override
  Future<XFile> takePicture(CameraController controller) async {
    return await dataSource.takePicture(controller);
  }
}