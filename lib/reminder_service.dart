import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._();
  static ReminderService get instance => _instance;

  // SharedPreference 키
  static const String reminderTimeKey = 'reminder_time';
  static const String lastAccessDateKey = 'last_access_date';
  static const String dailyAccessCountKey = 'daily_access_count';
  static const String totalAccessCountKey = 'total_access_count';
  static const String streakCountKey = 'streak_count';

  ReminderService._();

  // 앱 시작시 호출
  Future<void> trackAppAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getFormattedDate(DateTime.now());
    final lastAccessDate = prefs.getString(lastAccessDateKey);
    final totalAccess = prefs.getInt(totalAccessCountKey) ?? 0;

    // 전체 접속 횟수 증가
    await prefs.setInt(totalAccessCountKey, totalAccess + 1);

    // 오늘 첫 접속인 경우
    if (lastAccessDate != today) {
      // 스트릭 처리 (연속 접속일)
      if (lastAccessDate != null) {
        final yesterday = _getFormattedDate(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        if (lastAccessDate == yesterday) {
          // 연속 접속일 경우 스트릭 증가
          final currentStreak = prefs.getInt(streakCountKey) ?? 0;
          await prefs.setInt(streakCountKey, currentStreak + 1);
        } else {
          // 연속 접속이 끊어진 경우 스트릭 초기화
          await prefs.setInt(streakCountKey, 1);
        }
      } else {
        // 첫 접속인 경우 스트릭 1로 설정
        await prefs.setInt(streakCountKey, 1);
      }

      // 하루 접속 횟수 초기화
      await prefs.setInt(dailyAccessCountKey, 1);
      // 접속일 갱신
      await prefs.setString(lastAccessDateKey, today);
    } else {
      // 오늘 중복 접속인 경우
      final dailyAccess = prefs.getInt(dailyAccessCountKey) ?? 0;
      await prefs.setInt(dailyAccessCountKey, dailyAccess + 1);
    }
  }

  // 현재 설정된 알림 시간 가져오기
  Future<TimeOfDay?> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(reminderTimeKey);

    if (timeString == null) return null;

    final parts = timeString.split(':');
    if (parts.length != 2) return null;

    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // 알림 시간 저장
  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(reminderTimeKey, '${time.hour}:${time.minute}');
  }

  // 연속 접속 일수 가져오기
  Future<int> getStreakCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(streakCountKey) ?? 0;
  }

  // 오늘 접속 횟수 가져오기
  Future<int> getDailyAccessCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getFormattedDate(DateTime.now());
    final lastAccessDate = prefs.getString(lastAccessDateKey);

    // 오늘 접속하지 않았으면 0 반환
    if (lastAccessDate != today) {
      return 0;
    }

    return prefs.getInt(dailyAccessCountKey) ?? 0;
  }

  // 전체 접속 횟수 가져오기
  Future<int> getTotalAccessCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(totalAccessCountKey) ?? 0;
  }

  // 날짜 포맷 생성
  String _getFormattedDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
