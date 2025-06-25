import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class PhotoTab extends ConsumerStatefulWidget {
  const PhotoTab({Key? key}) : super(key: key);

  @override
  ConsumerState<PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends ConsumerState<PhotoTab> {
  String? selectedImagePath;
  String? selectedDepthPath;
  List<Offset> selectedPoints = [];
  double? measuredDistance;
  String selectedUnit = 'cm';
  List<MeasurementRecord> measurementHistory = [];

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 사진 선택 버튼
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('사진 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),

          const SizedBox(height: 16),

          // 선택된 사진 뷰어
          if (selectedImagePath != null) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GestureDetector(
                      onTapDown: _onImageTap,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(selectedImagePath!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
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
                          if (selectedPoints.length == 2)
                            CustomPaint(
                              painter: LinePainter(
                                point1: selectedPoints[0],
                                point2: selectedPoints[1],
                              ),
                              child: Container(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (measuredDistance != null)
                    Text(
                      '${measuredDistance!.toStringAsFixed(2)} $selectedUnit',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...['mm', 'cm', 'm'].map((unit) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(unit),
                          selected: selectedUnit == unit,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedUnit = unit;
                                _convertUnit();
                              });
                            }
                          },
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 측정 기록
            if (measurementHistory.isNotEmpty) ...[
              const Text(
                '측정 기록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                          onPressed: () => _deleteMeasurement(index),
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ] else ...[
            // 사진이 선택되지 않았을 때
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      '사진을 선택하여 거리 측정을 시작하세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          selectedImagePath = image.path;
          selectedPoints.clear();
          measuredDistance = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 선택에 실패했습니다: $e')),
      );
    }
  }

  void _onImageTap(TapDownDetails details) {
    if (selectedImagePath == null) return;

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
    if (selectedPoints.length != 2 || selectedDepthPath == null) return;

    try {
      const platform = MethodChannel('com.example.depth');
      final distance = await platform.invokeMethod<int>(
        'measurePhoto',
        {
          'depthPath': selectedDepthPath,
          'x1': selectedPoints[0].dx.toInt(),
          'y1': selectedPoints[0].dy.toInt(),
          'x2': selectedPoints[1].dx.toInt(),
          'y2': selectedPoints[1].dy.toInt(),
        },
      );

      setState(() {
        measuredDistance = (distance ?? 0) / 10.0; // mm를 cm로 변환
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

// 두 점 사이 선 그리기
class LinePainter extends CustomPainter {
  final Offset point1;
  final Offset point2;

  LinePainter({required this.point1, required this.point2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(point1, point2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}