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
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;
  int _streakCount = 0;
  int _dailyAccessCount = 0;
  int _totalAccessCount = 0;
  Map<String, dynamic>? uiLabels;
  late String selectedLang;

  @override
  void initState() {
    super.initState();
    // 메인 페이지에서 전달받은 언어 설정 사용
    selectedLang = widget.selectedLanguage;
    print('ReminderSettingPage - 초기 언어 설정: $selectedLang');
    _loadSettings();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      // JSON 파일 로딩
      final jsonString = await rootBundle.loadString(
        'assets/lucky_ten_ui_labels.json',
      );

      final Map<String, dynamic> labels = json.decode(jsonString);
      print('ReminderSettingPage - 사용 가능한 언어: ${labels.keys.toList()}');

      // 지원되지 않는 언어인 경우 기본값으로 한국어 사용
      if (!labels.containsKey(selectedLang)) {
        print('ReminderSettingPage - 지원되지 않는 언어: $selectedLang, 기본값(ko)으로 설정');
        selectedLang = 'ko';
      } else {
        print(
          'ReminderSettingPage - 선택된 언어 라벨: ${labels[selectedLang]?.keys.toList()}',
        );
      }

      if (mounted) {
        setState(() {
          uiLabels = labels;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ReminderSettingPage - 라벨 로딩 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    final reminderTime = await ReminderService.instance.getReminderTime();
    final streakCount = await ReminderService.instance.getStreakCount();
    final dailyAccessCount =
        await ReminderService.instance.getDailyAccessCount();
    final totalAccessCount =
        await ReminderService.instance.getTotalAccessCount();

    if (mounted) {
      setState(() {
        _selectedTime = reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
        _streakCount = streakCount;
        _dailyAccessCount = dailyAccessCount;
        _totalAccessCount = totalAccessCount;
      });
    }
  }

  Future<void> _selectTime() async {
    final labels = uiLabels?[selectedLang] as Map<String, dynamic>? ?? {};

    // 타임피커에 사용할 버튼 텍스트 - 다국어 지원을 위한 매핑
    final Map<String, String> timePickerText = {
      'ko': '취소',
      'en': 'Cancel',
      'ja': 'キャンセル',
      'zh': '取消',
      'es': 'Cancelar',
    };

    final Map<String, String> confirmText = {
      'ko': '확인',
      'en': 'Confirm',
      'ja': '確認',
      'zh': '确认',
      'es': 'Confirmar',
    };

    final Map<String, String> hourText = {
      'ko': '시',
      'en': 'Hour',
      'ja': '時',
      'zh': '时',
      'es': 'Hora',
    };

    final Map<String, String> minuteText = {
      'ko': '분',
      'en': 'Minute',
      'ja': '分',
      'zh': '分',
      'es': 'Minuto',
    };

    final Map<String, String> helpText = {
      'ko': '알림 시간 선택',
      'en': 'Select Time',
      'ja': '時間を選択',
      'zh': '选择时间',
      'es': 'Seleccionar hora',
    };

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: helpText[selectedLang] ?? '알림 시간 선택',
      cancelText: timePickerText[selectedLang] ?? '취소',
      confirmText: confirmText[selectedLang] ?? '확인',
      hourLabelText: hourText[selectedLang] ?? '시',
      minuteLabelText: minuteText[selectedLang] ?? '분',
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });

      await ReminderService.instance.setReminderTime(pickedTime);

      if (!mounted) return;

      // '설정 완료' 메시지 다국어 지원
      final Map<String, String> settingDoneMsg = {
        'ko':
            '${labels['check_time'] ?? '확인 시간'}: ${pickedTime.format(context)}',
        'en':
            '${labels['check_time'] ?? 'Check Time'}: ${pickedTime.format(context)}',
        'ja':
            '${labels['check_time'] ?? '確認時間'}: ${pickedTime.format(context)}',
        'zh':
            '${labels['check_time'] ?? '确认时间'}: ${pickedTime.format(context)}',
        'es':
            '${labels['check_time'] ?? 'Hora de verificación'}: ${pickedTime.format(context)}',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settingDoneMsg[selectedLang] ??
                '${labels['check_time'] ?? '확인 시간'}: ${pickedTime.format(context)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || uiLabels == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final labels = uiLabels![selectedLang] as Map<String, dynamic>? ?? {};

    // 디버그 정보
    print('현재 선택된 언어: $selectedLang');
    print('레이블 로드 여부: ${uiLabels != null}');
    if (uiLabels != null) {
      print('지원 언어: ${uiLabels!.keys.toList()}');
    }

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
                // 디버그 정보 (개발 중에만 사용, 나중에 제거)
                if (false) // 개발 중에만 true로 변경
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.amber.withOpacity(0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('현재 선택된 언어: $selectedLang'),
                        Text('레이블 로드 여부: ${uiLabels != null}'),
                        if (uiLabels != null)
                          Text('지원 언어: ${uiLabels!.keys.toList()}'),
                      ],
                    ),
                  ),
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
                        // 통계 항목을 위한 행
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Row(
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
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  labels['daily_check_time'] ?? '매일 확인 시간 설정',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels['daily_check_description'] ??
                      '매일 이 시간이 되면 십계명 카드를 확인하는 것을 잊지 마세요.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(labels['check_time'] ?? '확인 시간'),
                  subtitle: Text(_selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: _selectTime,
                ),
                const Divider(),
                const SizedBox(height: 16),
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
                    // 팁 1
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Expanded(
                            child: Text(
                              labels['tip_1'] ?? '매일 꾸준히 접속하면 연속 접속일이 늘어납니다.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 팁 2
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Expanded(
                            child: Text(
                              labels['tip_2'] ??
                                  '설정한 시간에 알림이 오지 않더라도 매일 앱을 열어 십계명을 확인하세요.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 팁 3
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Expanded(
                          child: Text(
                            labels['tip_3'] ??
                                '십계명 카드 내용을 메모해두면 나중에 모아볼 수 있습니다.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
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
          width: 80, // 고정된 너비로 설정하여 오버플로우 방지
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
}
