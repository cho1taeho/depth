import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:depth/core/depth_api/depth_api.dart';
import 'dart:io';

class VideoTab extends ConsumerStatefulWidget {
  const VideoTab({Key? key}) : super(key: key);

  @override
  ConsumerState<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends ConsumerState<VideoTab> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isRecordingDepth = false;
  String? _currentVideoPath;
  String? _currentDepthDataPath;
  int? _recordingTimestamp;
  List<Offset> selectedPoints = [];
  double? measuredDistance;
  String selectedUnit = 'cm';
  List<MeasurementRecord> measurementHistory = [];

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 깊이 데이터 수집 버튼들
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRecordingDepth ? null : _startDepthRecording,
                  icon: const Icon(Icons.sensors),
                  label: const Text('깊이 수집'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRecordingDepth ? _stopDepthRecording : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('수집 중지'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 동영상 선택 버튼
          ElevatedButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.video_library),
            label: const Text('동영상 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 16),
          // 상태 표시
          if (_isRecordingDepth) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('깊이 데이터 수집 중...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 동영상 플레이어
          if (_chewieController != null) ...[
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: GestureDetector(
                onTapDown: _onVideoTap,
                child: Stack(
                  children: [
                    Chewie(controller: _chewieController!),
                    // 선택된 점들 표시
                    ...selectedPoints.map((point) => Positioned(
                      left: point.dx - 10,
                      top: point.dy - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 측정 결과 표시
            if (measuredDistance != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '측정 거리: ${measuredDistance!.toStringAsFixed(2)} $selectedUnit',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: selectedUnit,
                      items: ['mm', 'cm', 'm'].map((unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit))
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedUnit = value;
                            _convertUnit();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveMeasurement,
                      child: const Text('측정 결과 저장'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearPoints,
                      child: const Text('점 초기화'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // 측정 기록
            if (measurementHistory.isNotEmpty) ...[
              const Text('측정 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: measurementHistory.length,
                  itemBuilder: (context, index) {
                    final record = measurementHistory[index];
                    return Card(
                      child: ListTile(
                        title: Text('${record.distance.toStringAsFixed(2)} ${record.unit}'),
                        subtitle: Text(record.timestamp),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteMeasurement(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ] else ...[
            // 동영상이 선택되지 않았을 때
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      '동영상을 선택하여 거리 측정을 시작하세요\n\n(깊이 데이터 수집 후 동영상 촬영을 권장합니다)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startDepthRecording() async {
    try {
      setState(() {
        _isRecordingDepth = true;
      });

      final result = await DepthApi.startVideoRecording();
      setState(() {
        _currentDepthDataPath = result['depthDataPath'] as String?;
        _recordingTimestamp = result['timestamp'] as int?;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('깊이 데이터 수집이 시작되었습니다.')),
      );
    } catch (e) {
      setState(() {
        _isRecordingDepth = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('깊이 데이터 수집에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _stopDepthRecording() async {
    try {
      final result = await DepthApi.stopVideoRecording();
      setState(() {
        _isRecordingDepth = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('깊이 데이터 수집이 완료되었습니다: $result')),
      );
    } catch (e) {
      setState(() {
        _isRecordingDepth = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('깊이 데이터 수집 중지에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _loadVideo(video.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동영상 선택에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _loadVideo(String videoPath) async {
    try {
      _videoController?.dispose();
      _chewieController?.dispose();

      _videoController = VideoPlayerController.file(File(videoPath));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
      );

      setState(() {
        _currentVideoPath = videoPath;
        selectedPoints.clear();
        measuredDistance = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동영상 로드에 실패했습니다: $e')),
      );
    }
  }

  void _onVideoTap(TapDownDetails details) {
    if (_videoController == null || _currentVideoPath == null) return;

    setState(() {
      if (selectedPoints.length < 2) {
        selectedPoints.add(details.localPosition);

        if (selectedPoints.length == 2) {
          _measureDistance();
        }
      } else {
        // 두 점이 이미 선택된 경우, 새로운 점으로 교체
        selectedPoints.clear();
        selectedPoints.add(details.localPosition);
        measuredDistance = null;
      }
    });
  }

  Future<void> _measureDistance() async {
    if (selectedPoints.length != 2 || _currentVideoPath == null || _videoController == null) return;

    try {
      final currentPosition = _videoController!.value.position.inMilliseconds;
      final distance = await DepthApi.measureVideoFrame(
        videoPath: _currentVideoPath!,
        frameTimestamp: currentPosition,
        x1: selectedPoints[0].dx.toInt(),
        y1: selectedPoints[0].dy.toInt(),
        x2: selectedPoints[1].dx.toInt(),
        y2: selectedPoints[1].dy.toInt(),
      );

      setState(() {
        measuredDistance = (distance) / 10.0; // mm를 cm로 변환
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거리 측정에 실패했습니다: $e')),
      );
    }
  }

  void _convertUnit() {
    if (measuredDistance == null) return;

    setState(() {
      switch (selectedUnit) {
        case 'mm':
          measuredDistance = measuredDistance! * 10;
          break;
        case 'cm':
        // 이미 cm 단위
          break;
        case 'm':
          measuredDistance = measuredDistance! / 100;
          break;
      }
    });
  }

  void _saveMeasurement() {
    if (measuredDistance == null) return;

    setState(() {
      measurementHistory.add(MeasurementRecord(
        distance: measuredDistance!,
        unit: selectedUnit,
        timestamp: DateTime.now().toString().substring(0, 19),
      ));
    });
  }

  void _deleteMeasurement(int index) {
    setState(() {
      measurementHistory.removeAt(index);
    });
  }

  void _clearPoints() {
    setState(() {
      selectedPoints.clear();
      measuredDistance = null;
    });
  }
}

// 측정 기록 클래스
class MeasurementRecord {
  final double distance;
  final String unit;
  final String timestamp;

  MeasurementRecord({
    required this.distance,
    required this.unit,
    required this.timestamp,
  });
}