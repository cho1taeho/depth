abstract interface class DepthDataSource {
  Future<String> takeDepthPicture();

  Future<void> savePictureToLocal(String filePath, List<int> imageBytes);
}