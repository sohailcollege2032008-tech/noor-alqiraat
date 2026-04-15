import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/data_providers.dart';
import 'quran_list_view.dart';
import 'mutoon_list_view.dart';
import 'audio_player_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const QuranListView(),
    const MutoonListView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? "القرآن الكريم" : "المتون العلمية"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث (مسح الذاكرة المؤقتة)',
            onPressed: () async {
              await Hive.box('availabilityCache').clear();
              ref.invalidate(fileAvailabilityProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم مسح الذاكرة المؤقتة وتحديث البيانات بنجاح!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
          const MiniPlayer(), // Persistent Audio Bottom Tray
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "القرآن",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: "المتون",
          ),
        ],
      ),
    );
  }
}
