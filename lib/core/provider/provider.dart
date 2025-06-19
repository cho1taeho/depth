import 'package:depth/domain/usecase/depth_usecase.dart';
import 'package:depth/presentation/viewmodel/depth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:depth/data/datasource/depth_data_source.dart';
import 'package:depth/data/datasource/depth_data_source_impl.dart';
import 'package:depth/data/repository/depth_repository.dart';
import 'package:depth/data/repository/depth_repository_impl.dart';




final depthDataSourceProvider = Provider<DepthDataSource>((ref) {
  return DepthDataSourceImpl();
});


final depthRepositoryProvider = Provider<DepthRepository>((ref) {
  final dataSource = ref.read(depthDataSourceProvider);
  return DepthRepositoryImpl(dataSource);
});


final depthUseCaseProvider = Provider<DepthUseCase>((ref) {
  final repository = ref.read(depthRepositoryProvider);
  return DepthUseCase(repository);
});

final depthViewModelProvider = ChangeNotifierProvider<DepthViewModel>((ref) {
  final useCase = ref.read(depthUseCaseProvider);
  return DepthViewModel(useCase);
});