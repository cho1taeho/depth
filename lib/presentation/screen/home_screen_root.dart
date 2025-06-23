import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_tab.dart';
import 'photo_tab.dart';
import 'video_tab.dart';

class HomeScreenRoot extends ConsumerStatefulWidget {
  const HomeScreenRoot({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreenRoot> createState() => _HomeScreenRootState();
}

class _HomeScreenRootState extends ConsumerState<HomeScreenRoot> {
  int _currentIndex = 0; // 0: 카메라탭, 1: 포토탭, 2: 동영상탭 (기본값: 카메라탭)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _getCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // 탭 전환
          });
        },
        type: BottomNavigationBarType.fixed, // 3개 이상 탭을 위해 필요
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: '카메라',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo),
            label: '사진',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: '동영상',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return '실시간 측정';
      case 1:
        return '사진 측정';
      case 2:
        return '동영상 측정';
      default:
        return '깊이 측정';
    }
  }

  Widget _getCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return CameraTab();
      case 1:
        return PhotoTab();
      case 2:
        return VideoTab();
      default:
        return CameraTab();
    }
  }
}