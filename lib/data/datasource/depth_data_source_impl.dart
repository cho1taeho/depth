import 'dart:io';

import 'package:depth/data/datasource/depth_data_source.dart';

class DepthDataSourceImpl implements DepthDataSource {
  @override
  Future<void> savePictureToLocal(String filePath, List<int> imageBytes) async {
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
  }

  @override
  Future<String> takeDepthPicture() async {
    throw UnimplementedError('Depth api 연동 필요');
  }

}