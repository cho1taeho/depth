abstract interface class DepthRepository {
  Future<String> takeDepthPicture();

  Future<void> savePictureToLocal(String filePath, List<int> imageBytes);
}