class DepthState {
  final bool isLoading;
  final String? filePath;
  final String? error;

  DepthState({
    required this.isLoading,
    this.filePath,
    this.error,
  });

  factory DepthState.initial() => DepthState(isLoading: false);

  DepthState copyWith({
    bool? isLoading,
    String? filePath,
    String? error,
  }) {
    return DepthState(
      isLoading: isLoading ?? this.isLoading,
      filePath: filePath ?? this.filePath,
      error: error,
    );
  }
}