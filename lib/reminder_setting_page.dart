import 'package:flutter/material.dart';
import 'reminder_service.dart';

class ReminderSettingPage extends StatefulWidget {
  const ReminderSettingPage({super.key});

  @override
  State<ReminderSettingPage> createState() => _ReminderSettingPageState();
}

class _ReminderSettingPageState extends State<ReminderSettingPage> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;
  int _streakCount = 0;
  int _dailyAccessCount = 0;
  int _totalAccessCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final reminderTime = await ReminderService.instance.getReminderTime();
    final streakCount = await ReminderService.instance.getStreakCount();
    final dailyAccessCount =
        await ReminderService.instance.getDailyAccessCount();
    final totalAccessCount =
        await ReminderService.instance.getTotalAccessCount();

    setState(() {
      _selectedTime = reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
      _streakCount = streakCount;
      _dailyAccessCount = dailyAccessCount;
      _totalAccessCount = totalAccessCount;
      _isLoading = false;
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: '알림 시간 선택',
      cancelText: '취소',
      confirmText: '확인',
      hourLabelText: '시',
      minuteLabelText: '분',
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });

      await ReminderService.instance.setReminderTime(pickedTime);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('매일 생각할 시간이 ${pickedTime.format(context)}로 설정되었습니다'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 십계명 기록'),
        backgroundColor: const Color(0xffdcd0f7),
      ),
      body: SingleChildScrollView(
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
                      const Text(
                        '나의 십계명 기록',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            '연속 접속일',
                            _streakCount,
                            Icons.local_fire_department,
                            Colors.orange,
                          ),
                          _buildStatItem(
                            '오늘 접속',
                            _dailyAccessCount,
                            Icons.today,
                            Colors.blue,
                          ),
                          _buildStatItem(
                            '전체 접속',
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
              const Text(
                '매일 확인 시간 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '매일 이 시간이 되면 십계명 카드를 확인하는 것을 잊지 마세요.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('확인 시간'),
                subtitle: Text(_selectedTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: _selectTime,
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                '사용 팁',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• 매일 꾸준히 접속하면 연속 접속일이 늘어납니다.\n'
                '• 설정한 시간에 알림이 오지 않더라도 매일 앱을 열어 십계명을 확인하세요.\n'
                '• 십계명 카드 내용을 메모해두면 나중에 모아볼 수 있습니다.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
