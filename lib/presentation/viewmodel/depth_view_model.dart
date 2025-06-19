import 'package:camera/camera.dart';
import 'package:depth/domain/usecase/depth_usecase.dart';
import 'package:depth/presentation/state/depth_state.dart';
import 'package:flutter/material.dart';

class DepthViewModel extends ChangeNotifier {
  final DepthUseCase useCase;

  DepthState _state = DepthState.initial();

  DepthState get state => _state;

  DepthViewModel(this.useCase);

  Future<void> takeDepthPicture(CameraController? controller) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    if (controller == null) {
      _state = _state.copyWith(
        isLoading: false,
        error: '카메라 컨트롤러가 초기화되지 않았습니다.',
      );
      notifyListeners();
      return;
    }

    try {
      final XFile file = await controller.takePicture();
      _state = _state.copyWith(
        isLoading: false,
        filePath: file.path,
        error: null,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }

  Future<void> savePictureToLocal(String filePath, List<int> imageBytes) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    final result = await useCase.savePictureToLocal(filePath, imageBytes);
    _state = result;
    notifyListeners();
  }
}
