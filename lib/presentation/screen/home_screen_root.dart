import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_tab.dart';
import 'photo_tab.dart';

class HomeScreenRoot extends ConsumerStatefulWidget {
  const HomeScreenRoot({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreenRoot> createState() => _HomeScreenRootState();
}

class _HomeScreenRootState extends ConsumerState<HomeScreenRoot> {
  int _currentIndex = 0; // 0: 카메라탭, 1: 포토탭 (기본값: 카메라탭)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '실시간 측정' : '사진 측정'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _currentIndex == 0 ? CameraTab() : PhotoTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // 탭 전환
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: '카메라',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo),
            label: '사진',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}