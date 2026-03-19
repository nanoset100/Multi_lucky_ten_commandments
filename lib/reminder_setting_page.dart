import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'reminder_service.dart';

class ReminderSettingPage extends StatefulWidget {
  final String selectedLanguage;

  const ReminderSettingPage({super.key, required this.selectedLanguage});

  @override
  State<ReminderSettingPage> createState() => _ReminderSettingPageState();
}

class _ReminderSettingPageState extends State<ReminderSettingPage> {
  bool _isLoading = true;
  int _streakCount = 0;
  int _dailyAccessCount = 0;
  int _totalAccessCount = 0;
  Map<String, dynamic>? uiLabels;
  late String selectedLang;

  @override
  void initState() {
    super.initState();
    selectedLang = widget.selectedLanguage;
    _loadSettings();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/lucky_ten_ui_labels.json',
      );
      final Map<String, dynamic> labels = json.decode(jsonString);

      if (!labels.containsKey(selectedLang)) {
        selectedLang = 'ko';
      }

      if (mounted) {
        setState(() {
          uiLabels = labels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    final streakCount = await ReminderService.instance.getStreakCount();
    final dailyAccessCount =
        await ReminderService.instance.getDailyAccessCount();
    final totalAccessCount =
        await ReminderService.instance.getTotalAccessCount();

    if (mounted) {
      setState(() {
        _streakCount = streakCount;
        _dailyAccessCount = dailyAccessCount;
        _totalAccessCount = totalAccessCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || uiLabels == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final labels = uiLabels![selectedLang] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          labels['reminder_page_title'] ?? '나의 십계명 기록',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xffdcd0f7),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          labels['stats_title'] ?? '나의 십계명 기록',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              labels['streak_days'] ?? '연속 접속일',
                              _streakCount,
                              Icons.local_fire_department,
                              Colors.orange,
                            ),
                            _buildStatItem(
                              labels['today_access'] ?? '오늘 접속',
                              _dailyAccessCount,
                              Icons.today,
                              Colors.blue,
                            ),
                            _buildStatItem(
                              labels['total_access'] ?? '전체 접속',
                              _totalAccessCount,
                              Icons.bar_chart,
                              Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  labels['usage_tips'] ?? '사용 팁',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTip(labels['tip_1'] ?? '매일 꾸준히 접속하면 연속 접속일이 늘어납니다.'),
                    _buildTip(labels['tip_2'] ?? '매일 아침 9시에 알림이 도착합니다.'),
                    _buildTip(
                      labels['tip_3'] ??
                          '십계명 카드 내용을 메모해두면 나중에 모아볼 수 있습니다.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: Colors.grey)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
