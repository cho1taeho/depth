import 'package:depth/data/repository/depth_repository.dart';
import 'package:depth/presentation/state/depth_state.dart';

class DepthUseCase {
  final DepthRepository repository;

  DepthUseCase(this.repository);

  Future<DepthState> takeDepthPicture() async {
    try {
      final filePath = await repository.takeDepthPicture();
      return DepthState(
        isLoading: false,
        filePath: filePath,
        error: null,
      );
    } catch (e) {
      return DepthState(
        isLoading: false,
        filePath: null,
        error: e.toString(),
      );
    }
  }

  Future<DepthState> savePictureToLocal(String filePath, List<int> imageBytes) async {
    try {
      await repository.savePictureToLocal(filePath, imageBytes);
      return DepthState(
        isLoading: false,
        filePath: filePath,
        error: null,
      );
    } catch (e) {
      return DepthState(
        isLoading: false,
        filePath: null,
        error: e.toString(),
      );
    }
  }

}