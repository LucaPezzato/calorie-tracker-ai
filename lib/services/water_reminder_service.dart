import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/nutrition_models.dart';

class WaterReminderService {
  WaterReminderService._();
  static final WaterReminderService instance = WaterReminderService._();

  static const int _baseNotificationId = 2000;
  static const int _maxSlots = 24;
  static const String _channelId = 'water_reminders';
  static const String _channelName = 'Promemoria Idratazione';
  static const String _channelDescription =
      'Notifiche periodiche per ricordarti di bere acqua durante il giorno.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const List<String> _messages = [
    'È ora di bere un bicchiere d\'acqua! 💧',
    'Pausa idratazione: mantieni il tuo obiettivo giornaliero! 🥤',
    'Un sorso d\'acqua ora fa la differenza su energia e concentrazione.',
    'Ricordati di idratarti: aggiungi 250 ml dal widget o dall\'app! 💧',
  ];

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _configureLocalTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  void _configureLocalTimezone() {
    final nowOffsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    // Prefer Europe/Rome if it matches current system offset
    try {
      final rome = tz.getLocation('Europe/Rome');
      if (rome.currentTimeZone.offset == nowOffsetMs) {
        tz.setLocalLocation(rome);
        return;
      }
    } catch (_) {}

    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == nowOffsetMs) {
        tz.setLocalLocation(loc);
        return;
      }
    }
    tz.setLocalLocation(tz.UTC);
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Generates daily reminder slots within [startMinutes, endMinutes].
  /// No notification is ever scheduled after [endMinutes] (evening quiet hours).
  static List<TimeOfDay> computeSlots({
    required int startMinutes,
    required int endMinutes,
    required int intervalMinutes,
  }) {
    final safeStart = startMinutes.clamp(0, 23 * 60 + 59);
    final safeEnd = endMinutes.clamp(safeStart, 23 * 60 + 59);
    final safeInterval = intervalMinutes.clamp(30, 360);

    final slots = <TimeOfDay>[];
    int current = safeStart;
    while (current <= safeEnd && slots.length < _maxSlots) {
      slots.add(TimeOfDay(hour: current ~/ 60, minute: current % 60));
      current += safeInterval;
    }
    return slots;
  }

  static String formatMinutes(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, 23 * 60 + 59);
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );
  }

  Future<void> cancelAllWaterReminders() async {
    await initialize();
    for (int i = 0; i < _maxSlots + 4; i++) {
      await _plugin.cancel(id: _baseNotificationId + i);
    }
  }

  Future<void> syncSchedule(UserProfile profile) async {
    await initialize();
    await cancelAllWaterReminders();

    if (!profile.waterReminderEnabled) return;

    final slots = computeSlots(
      startMinutes: profile.waterReminderStartMinutes,
      endMinutes: profile.waterReminderEndMinutes,
      intervalMinutes: profile.waterReminderIntervalMinutes,
    );

    final now = tz.TZDateTime.now(tz.local);
    final details = _notificationDetails();

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        slot.hour,
        slot.minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _baseNotificationId + i,
        title: 'Promemoria Acqua 💧',
        body: _messages[i % _messages.length],
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> sendTestNotification() async {
    await initialize();
    await _plugin.show(
      id: _baseNotificationId + 99,
      title: 'Promemoria Acqua 💧',
      body: 'Notifica attiva! Riceverai i promemoria solo nella fascia oraria scelta.',
      notificationDetails: _notificationDetails(),
    );
  }
}
