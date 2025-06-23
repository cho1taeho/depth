import 'package:flutter/services.dart';

// 네이티브 연결 채널
class DepthApi {
  static const _channel = MethodChannel('com.example.depth');

  static Future<void> initSession() async {
    await _channel.invokeMethod('initSession');
  }

  static Future<Map<String, dynamic>> capturePhotoWithDepth() async {
    final result = await _channel.invokeMethod('capturePhotoWithDepth');
    return Map<String, dynamic>.from(result);
  }
  
  // 동영상 촬영 시작
  static Future<Map<String, dynamic>> startVideoRecording() async {
    final result = await _channel.invokeMethod('startVideoRecording');
    return Map<String, dynamic>.from(result);
  }
  
  // 동영상 촬영 중지
  static Future<String> stopVideoRecording() async {
    final result = await _channel.invokeMethod('stopVideoRecording');
    return result as String;
  }
  
  // 동영상 프레임에서 거리 측정
  static Future<int> measureVideoFrame({
    required String videoPath,
    required int frameTimestamp,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
  }) async {
    final result = await _channel.invokeMethod('measureVideoFrame', {
      'videoPath': videoPath,
      'frameTimestamp': frameTimestamp,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    });
    return result as int;
  }
}