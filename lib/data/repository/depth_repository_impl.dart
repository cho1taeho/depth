import 'package:depth/data/datasource/depth_data_source.dart';
import 'package:depth/data/repository/depth_repository.dart';

class DepthRepositoryImpl implements DepthRepository {
  final DepthDataSource _depthDataSource;

  DepthRepositoryImpl(this._depthDataSource);

  @override
  Future<String> takeDepthPicture() async {
    final filePath = await _depthDataSource.takeDepthPicture();
    return filePath;
  }

  @override
  Future<void> savePictureToLocal(String filePath, List<int> imageBytes) async {
    await _depthDataSource.savePictureToLocal(filePath, imageBytes);
  }
}