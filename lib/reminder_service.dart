import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱의 알림 및 사용자 통계 관리를 위한 서비스
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  static ReminderService get instance => _instance;

  // 싱글톤 패턴 구현
  ReminderService._internal();

  // 공유 환경설정 캐싱
  SharedPreferences? _prefs;

  // 키 상수
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';
  static const String _keyStreakCount = 'streak_count';
  static const String _keyDailyAccessCount = 'daily_access_count';
  static const String _keyTotalAccessCount = 'total_access_count';
  static const String _keyLastAccessDate = 'last_access_date';

  /// 서비스 초기화
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _updateAccessStats();
  }

  /// 알림 시간 설정
  Future<void> setReminderTime(TimeOfDay time) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_keyReminderHour, time.hour);
    await _prefs!.setInt(_keyReminderMinute, time.minute);
  }

  /// 알림 시간 가져오기
  Future<TimeOfDay?> getReminderTime() async {
    _prefs ??= await SharedPreferences.getInstance();

    final hour = _prefs!.getInt(_keyReminderHour);
    final minute = _prefs!.getInt(_keyReminderMinute);

    if (hour != null && minute != null) {
      return TimeOfDay(hour: hour, minute: minute);
    }

    return null;
  }

  /// 접속 통계 업데이트
  Future<void> _updateAccessStats() async {
    _prefs ??= await SharedPreferences.getInstance();

    // 오늘 날짜 (YYYY-MM-DD 형식)
    final today = DateTime.now().toString().split(' ')[0];

    // 마지막 접속일
    final lastAccessDate = _prefs!.getString(_keyLastAccessDate);

    // 총 접속 횟수 증가
    final totalCount = (_prefs!.getInt(_keyTotalAccessCount) ?? 0) + 1;
    await _prefs!.setInt(_keyTotalAccessCount, totalCount);

    if (lastAccessDate == today) {
      // 오늘 이미 접속했던 경우: 일일 접속 횟수만 증가
      final dailyCount = (_prefs!.getInt(_keyDailyAccessCount) ?? 0) + 1;
      await _prefs!.setInt(_keyDailyAccessCount, dailyCount);
    } else {
      // 오늘 첫 접속인 경우

      // 일일 접속 횟수 리셋
      await _prefs!.setInt(_keyDailyAccessCount, 1);

      // 연속 접속일 처리
      if (lastAccessDate != null) {
        final yesterday =
            DateTime.now()
                .subtract(const Duration(days: 1))
                .toString()
                .split(' ')[0];

        if (lastAccessDate == yesterday) {
          // 어제 접속했다면 연속 접속일 증가
          final streakCount = (_prefs!.getInt(_keyStreakCount) ?? 0) + 1;
          await _prefs!.setInt(_keyStreakCount, streakCount);
        } else {
          // 연속 접속이 끊겼다면 리셋
          await _prefs!.setInt(_keyStreakCount, 1);
        }
      } else {
        // 첫 접속이라면 연속 접속일 1로 설정
        await _prefs!.setInt(_keyStreakCount, 1);
      }
    }

    // 마지막 접속일 업데이트
    await _prefs!.setString(_keyLastAccessDate, today);
  }

  /// 연속 접속일 가져오기
  Future<int> getStreakCount() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getInt(_keyStreakCount) ?? 0;
  }

  /// 오늘 접속 횟수 가져오기
  Future<int> getDailyAccessCount() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getInt(_keyDailyAccessCount) ?? 0;
  }

  /// 총 접속 횟수 가져오기
  Future<int> getTotalAccessCount() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getInt(_keyTotalAccessCount) ?? 0;
  }

  /// 모든 데이터 리셋 (디버깅용)
  Future<void> resetAllData() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_keyReminderHour);
    await _prefs!.remove(_keyReminderMinute);
    await _prefs!.remove(_keyStreakCount);
    await _prefs!.remove(_keyDailyAccessCount);
    await _prefs!.remove(_keyTotalAccessCount);
    await _prefs!.remove(_keyLastAccessDate);
  }
}
