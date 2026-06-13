import 'dart:math' as math;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiXiaoJiApp());
}

class LiXiaoJiApp extends StatelessWidget {
  const LiXiaoJiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '礼小记',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF12530)),
        scaffoldBackgroundColor: const Color(0xFFFFF2F4),
      ),
      home: const AppSplashPage(),
    );
  }
}

class AppSplashPage extends StatefulWidget {
  const AppSplashPage({super.key});

  @override
  State<AppSplashPage> createState() => _AppSplashPageState();
}

class _AppSplashPageState extends State<AppSplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('relation/Home Page.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

enum GiftRecordType { received, returned }

enum BottomTabType { home, relationship, added, data, calendar }

enum _StatsPeriod { month, year, all }

extension _StatsPeriodX on _StatsPeriod {
  String get label {
    switch (this) {
      case _StatsPeriod.month:
        return '本月';
      case _StatsPeriod.year:
        return '本年';
      case _StatsPeriod.all:
        return '全部';
    }
  }

  String get overviewTitle {
    switch (this) {
      case _StatsPeriod.month:
        return '本月收支总览';
      case _StatsPeriod.year:
        return '本年收支总览';
      case _StatsPeriod.all:
        return '全部收支总览';
    }
  }
}

enum RelationGroup { friend, classmate, colleague, relative, neighbor, other }

extension RelationGroupX on RelationGroup {
  String get label {
    switch (this) {
      case RelationGroup.friend:
        return '朋友';
      case RelationGroup.classmate:
        return '同学';
      case RelationGroup.colleague:
        return '同事';
      case RelationGroup.relative:
        return '亲戚';
      case RelationGroup.neighbor:
        return '邻居';
      case RelationGroup.other:
        return '其他';
    }
  }
}

class ContactProfile {
  const ContactProfile({
    required this.id,
    required this.name,
    required this.group,
    required this.note,
  });

  final int id;
  final String name;
  final RelationGroup group;
  final String note;

  ContactProfile copyWith({
    int? id,
    String? name,
    RelationGroup? group,
    String? note,
  }) {
    return ContactProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'group': group.name, 'note': note};
  }

  factory ContactProfile.fromJson(Map<String, dynamic> json) {
    final rawGroup = json['group']?.toString() ?? RelationGroup.other.name;
    final group = RelationGroup.values.firstWhere(
      (item) => item.name == rawGroup,
      orElse: () => RelationGroup.other,
    );
    return ContactProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      group: group,
      note: json['note']?.toString() ?? '',
    );
  }
}

class GiftRecord {
  const GiftRecord({
    required this.id,
    required this.contactId,
    required this.type,
    required this.amount,
    required this.date,
    required this.occasion,
    required this.note,
  });

  final int id;
  final int contactId;
  final GiftRecordType type;
  final int amount;
  final DateTime date;
  final String occasion;
  final String note;

  int get signedAmount => type == GiftRecordType.received ? amount : -amount;

  GiftRecord copyWith({
    int? id,
    int? contactId,
    GiftRecordType? type,
    int? amount,
    DateTime? date,
    String? occasion,
    String? note,
  }) {
    return GiftRecord(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      occasion: occasion ?? this.occasion,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'occasion': occasion,
      'note': note,
    };
  }

  factory GiftRecord.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? GiftRecordType.received.name;
    final type = GiftRecordType.values.firstWhere(
      (item) => item.name == rawType,
      orElse: () => GiftRecordType.received,
    );
    return GiftRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      contactId: (json['contactId'] as num?)?.toInt() ?? 0,
      type: type,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      occasion: json['occasion']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class RecordDraft {
  const RecordDraft({
    required this.type,
    required this.amount,
    required this.date,
    required this.occasion,
    required this.note,
  });

  final GiftRecordType type;
  final int amount;
  final DateTime date;
  final String occasion;
  final String note;
}

class ContactDraft {
  const ContactDraft({
    required this.name,
    required this.group,
    required this.note,
  });

  final String name;
  final RelationGroup group;
  final String note;
}

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.dateTime,
    required this.person,
    required this.title,
    required this.note,
  });

  final int id;
  final DateTime dateTime;
  final String person;
  final String title;
  final String note;

  CalendarEntry copyWith({
    DateTime? dateTime,
    String? person,
    String? title,
    String? note,
  }) {
    return CalendarEntry(
      id: id,
      dateTime: dateTime ?? this.dateTime,
      person: person ?? this.person,
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'person': person,
      'title': title,
      'note': note,
    };
  }

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    return CalendarEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dateTime:
          DateTime.tryParse(json['dateTime']?.toString() ?? '') ??
          DateTime.now(),
      person: json['person']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class CalendarEntryDraft {
  const CalendarEntryDraft({
    required this.dateTime,
    required this.person,
    required this.title,
    required this.note,
  });

  final DateTime dateTime;
  final String person;
  final String title;
  final String note;
}

class _CalendarEntryEditorResult {
  const _CalendarEntryEditorResult.save(this.draft) : shouldDelete = false;

  const _CalendarEntryEditorResult.delete() : draft = null, shouldDelete = true;

  final CalendarEntryDraft? draft;
  final bool shouldDelete;
}

const String kReminderEnabledKey = 'settings.reminders.enabled.v1';

class _CalendarReminderScheduler {
  _CalendarReminderScheduler._();

  static final _CalendarReminderScheduler instance =
      _CalendarReminderScheduler._();

  static const String _channelId = 'calendar_reminder_channel';
  static const String _channelName = 'Calendar Reminders';
  static const String _channelDescription =
      'Reminders for upcoming calendar events';
  static const int _idBase = 880000;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    tzdata.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleForEntry(CalendarEntry entry) async {
    if (kIsWeb) return;

    await initialize();

    final reminderTime = entry.dateTime.subtract(const Duration(days: 1));
    final now = DateTime.now();
    if (!reminderTime.isAfter(now)) {
      await cancelForEntry(entry.id);
      return;
    }

    final title = '明日提醒：${entry.title}';
    final body =
        '明天 ${_formatDate(entry.dateTime)} ${_formatTime(entry.dateTime)}'
        ' 与 ${entry.person} 相关事项，请留意。';

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      _idBase + entry.id,
      title,
      body,
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'calendar_entry_${entry.id}',
    );
  }

  Future<void> syncAll(Iterable<CalendarEntry> entries) async {
    await initialize();
    for (final entry in entries) {
      await scheduleForEntry(entry);
    }
  }

  Future<void> cancelForEntry(int entryId) async {
    if (kIsWeb) return;

    await initialize();
    await _notificationsPlugin.cancel(_idBase + entryId);
  }

  Future<void> cancelAllManaged() async {
    if (kIsWeb) return;

    await initialize();
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final item in pending) {
      if (item.id >= _idBase && item.id < _idBase + 5000000) {
        await _notificationsPlugin.cancel(item.id);
      }
    }
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final zoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zoneName));
    } catch (_) {
      // Fall back to default timezone when the platform does not expose it.
      tz.setLocalLocation(tz.local);
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _contactsStorageKey = 'home.contacts.v1';
  static const String _recordsStorageKey = 'home.records.v1';
  static const String _calendarStorageKey = 'home.calendar.v1';
  static const String _activeTypeStorageKey = 'home.active_type.v1';

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final List<ContactProfile> _contacts;
  late final List<GiftRecord> _records;
  late final List<CalendarEntry> _calendarEntries;
  late int _nextContactId;
  late int _nextRecordId;
  late int _nextCalendarEntryId;
  late final Map<RelationGroup, bool> _groupExpanded;

  GiftRecordType _activeType = GiftRecordType.received;
  BottomTabType _activeBottomTab = BottomTabType.home;
  _StatsPeriod _activeStatsPeriod = _StatsPeriod.month;
  bool _remindersEnabled = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _contacts = <ContactProfile>[];
    _records = <GiftRecord>[];
    _calendarEntries = <CalendarEntry>[];
    _nextContactId = 1;
    _nextRecordId = 1;
    _nextCalendarEntryId = 1;
    _groupExpanded = {for (final group in RelationGroup.values) group: true};
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchChanged);
    _loadPersistedData();
  }

  void _recalculateNextIds() {
    _nextContactId =
        (_contacts.fold<int>(0, (maxId, c) => c.id > maxId ? c.id : maxId)) + 1;
    _nextRecordId =
        (_records.fold<int>(0, (maxId, r) => r.id > maxId ? r.id : maxId)) + 1;
    _nextCalendarEntryId =
        (_calendarEntries.fold<int>(
          0,
          (maxId, entry) => entry.id > maxId ? entry.id : maxId,
        )) +
        1;
  }

  List<Map<String, dynamic>> _decodeJsonList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedContacts =
        _decodeJsonList(prefs.getString(_contactsStorageKey))
            .map(ContactProfile.fromJson)
            .where((item) => item.id > 0 && item.name.trim().isNotEmpty)
            .toList();
    final persistedRecords =
        _decodeJsonList(prefs.getString(_recordsStorageKey))
            .map(GiftRecord.fromJson)
            .where((item) => item.id > 0 && item.contactId > 0)
            .toList();
    final persistedCalendar = _decodeJsonList(
      prefs.getString(_calendarStorageKey),
    ).map(CalendarEntry.fromJson).where((item) => item.id > 0).toList();

    final persistedType = prefs.getString(_activeTypeStorageKey);
    final activeType = GiftRecordType.values.firstWhere(
      (item) => item.name == persistedType,
      orElse: () => GiftRecordType.received,
    );
    final remindersEnabled = prefs.getBool(kReminderEnabledKey) ?? false;

    if (!mounted) return;
    setState(() {
      _contacts
        ..clear()
        ..addAll(persistedContacts);
      _records
        ..clear()
        ..addAll(persistedRecords);
      _calendarEntries
        ..clear()
        ..addAll(persistedCalendar);
      _activeType = activeType;
      _remindersEnabled = remindersEnabled;
      _recalculateNextIds();
    });
    await _syncCalendarReminders();
  }

  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsStorageKey,
      jsonEncode(_contacts.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _recordsStorageKey,
      jsonEncode(_records.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _calendarStorageKey,
      jsonEncode(_calendarEntries.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_activeTypeStorageKey, _activeType.name);
  }

  void _applyDataChange(VoidCallback change) {
    setState(change);
    _persistData();
  }

  Future<void> _syncCalendarReminders() async {
    await _CalendarReminderScheduler.instance.initialize();
    if (!_remindersEnabled) {
      await _CalendarReminderScheduler.instance.cancelAllManaged();
      return;
    }
    await _CalendarReminderScheduler.instance.requestPermission();
    await _CalendarReminderScheduler.instance.syncAll(_calendarEntries);
  }

  Future<void> _onReminderSettingChanged(bool enabled) async {
    _remindersEnabled = enabled;
    await _syncCalendarReminders();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _switchLedgerType(GiftRecordType type) {
    if (_activeType == type) return;
    setState(() {
      _activeType = type;
    });
    _persistData();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _onBottomTabTap(BottomTabType tab) {
    if (_activeBottomTab == tab) return;
    _searchFocusNode.unfocus();
    setState(() {
      _activeBottomTab = tab;
    });
  }

  bool get _showBackAction {
    return _searchFocusNode.hasFocus ||
        _searchController.text.trim().isNotEmpty;
  }

  String get _bottomTabImageAsset {
    switch (_activeBottomTab) {
      case BottomTabType.home:
        return 'tab/home.png';
      case BottomTabType.relationship:
        return 'tab/relationship.png';
      case BottomTabType.added:
        return 'tab/added.png';
      case BottomTabType.data:
        return 'tab/data.png';
      case BottomTabType.calendar:
        return 'tab/calendar.png';
    }
  }

  ContactProfile? _contactById(int contactId) {
    for (final contact in _contacts) {
      if (contact.id == contactId) return contact;
    }
    return null;
  }

  List<GiftRecord> get _activeRecords {
    return _records.where((record) => record.type == _activeType).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<GiftRecord> get _filteredRecords {
    final source = _activeRecords;
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return source;
    return source.where((record) {
      final contact = _contactById(record.contactId);
      if (contact == null) return false;
      final text = [
        contact.name,
        contact.group.label,
        record.occasion,
        record.note,
        _formatDate(record.date),
        record.amount.toString(),
      ].join(' ').toLowerCase();
      return text.contains(keyword);
    }).toList();
  }

  int _netForContact(int contactId) {
    var net = 0;
    for (final record in _records) {
      if (record.contactId == contactId) {
        net += record.signedAmount;
      }
    }
    return net;
  }

  List<GiftRecord> _recordsForContact(int contactId) {
    return _records.where((record) => record.contactId == contactId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _tryDeleteRecord(GiftRecord record) async {
    final contact = _contactById(record.contactId);
    if (contact == null) return;
    final shouldDelete = await _showDeleteRecordSheet(record, contact);
    if (shouldDelete != true || !mounted) return;
    _applyDataChange(() {
      _records.removeWhere((item) => item.id == record.id);
    });
  }

  Future<bool?> _showDeleteRecordSheet(
    GiftRecord record,
    ContactProfile contact,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return _HomeDeleteRecordSheet(
          onConfirm: () => Navigator.of(sheetContext).pop(true),
        );
      },
    );
  }

  Future<bool?> _showDeleteContactSheet(ContactProfile contact) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return _DeleteContactSheet(
          contactName: contact.name,
          onConfirm: () => Navigator.of(sheetContext).pop(true),
        );
      },
    );
  }

  void _upsertRecord({
    required int contactId,
    required RecordDraft draft,
    GiftRecord? original,
  }) {
    _applyDataChange(() {
      if (original == null) {
        _records.add(
          GiftRecord(
            id: _nextRecordId++,
            contactId: contactId,
            type: draft.type,
            amount: draft.amount,
            date: draft.date,
            occasion: draft.occasion,
            note: draft.note,
          ),
        );
      } else {
        final index = _records.indexWhere((record) => record.id == original.id);
        if (index >= 0) {
          _records[index] = _records[index].copyWith(
            type: draft.type,
            amount: draft.amount,
            date: draft.date,
            occasion: draft.occasion,
            note: draft.note,
          );
        }
      }
    });
  }

  Future<void> _openContactDetail(ContactProfile contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactDetailPage(
          contact: contact,
          recordsForContact: () => _recordsForContact(contact.id),
          onCreateRecord: (draft) =>
              _upsertRecord(contactId: contact.id, draft: draft),
          onEditRecord: (record, draft) => _upsertRecord(
            contactId: contact.id,
            draft: draft,
            original: record,
          ),
          onDeleteRecord: (record) {
            _applyDataChange(() {
              _records.removeWhere((item) => item.id == record.id);
            });
          },
          onDeleteContact: () async {
            final shouldDelete = await _showDeleteContactSheet(contact);
            if (shouldDelete == true && mounted) {
              _applyDataChange(() {
                _records.removeWhere(
                  (record) => record.contactId == contact.id,
                );
                _contacts.removeWhere((item) => item.id == contact.id);
              });
              return true;
            }
            return false;
          },
          netAmount: () => _netForContact(contact.id),
          groupLabel: contact.group.label,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openAddContactSheet() async {
    final draft = await showModalBottomSheet<ContactDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => const _ContactEditorSheet(),
    );
    if (draft == null || !mounted) return;
    _applyDataChange(() {
      _contacts.add(
        ContactProfile(
          id: _nextContactId++,
          name: draft.name,
          group: draft.group,
          note: draft.note,
        ),
      );
      _groupExpanded[draft.group] = true;
    });
  }

  void _createRecordFromAddTab({
    required String contactName,
    required RelationGroup group,
    required RecordDraft draft,
  }) {
    final normalizedName = contactName.trim();
    if (normalizedName.isEmpty) return;

    _applyDataChange(() {
      var contactId = -1;
      for (final contact in _contacts) {
        if (contact.name.toLowerCase() == normalizedName.toLowerCase()) {
          contactId = contact.id;
          break;
        }
      }

      if (contactId < 0) {
        contactId = _nextContactId++;
        _contacts.add(
          ContactProfile(
            id: contactId,
            name: normalizedName,
            group: group,
            note: '',
          ),
        );
        _groupExpanded[group] = true;
      }

      _records.add(
        GiftRecord(
          id: _nextRecordId++,
          contactId: contactId,
          type: draft.type,
          amount: draft.amount,
          date: draft.date,
          occasion: draft.occasion,
          note: draft.note,
        ),
      );
      _activeType = draft.type;
      _activeBottomTab = BottomTabType.home;
    });
  }

  void _createCalendarEntry(CalendarEntryDraft draft) {
    late final CalendarEntry createdEntry;
    _applyDataChange(() {
      createdEntry = CalendarEntry(
        id: _nextCalendarEntryId++,
        dateTime: draft.dateTime,
        person: draft.person,
        title: draft.title,
        note: draft.note,
      );
      _calendarEntries.add(createdEntry);
    });
    if (_remindersEnabled) {
      _CalendarReminderScheduler.instance.scheduleForEntry(createdEntry);
    }
  }

  void _updateCalendarEntry(CalendarEntry entry, CalendarEntryDraft draft) {
    CalendarEntry? updatedEntry;
    _applyDataChange(() {
      final index = _calendarEntries.indexWhere((item) => item.id == entry.id);
      if (index < 0) return;
      updatedEntry = entry.copyWith(
        dateTime: draft.dateTime,
        person: draft.person,
        title: draft.title,
        note: draft.note,
      );
      _calendarEntries[index] = updatedEntry!;
    });
    if (_remindersEnabled && updatedEntry != null) {
      _CalendarReminderScheduler.instance.scheduleForEntry(updatedEntry!);
    }
  }

  void _deleteCalendarEntry(CalendarEntry entry) {
    _applyDataChange(() {
      _calendarEntries.removeWhere((item) => item.id == entry.id);
    });
    _CalendarReminderScheduler.instance.cancelForEntry(entry.id);
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          initialRemindersEnabled: _remindersEnabled,
          onReminderChanged: _onReminderSettingChanged,
        ),
      ),
    );
  }

  Widget _buildHomeTabBody(List<GiftRecord> records) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showBackAction
                ? SizedBox(
                    key: const ValueKey('back-header'),
                    height: 52,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF2E2E2E),
                          size: 27,
                        ),
                      ),
                    ),
                  )
                : const _BrandHeader(key: ValueKey('brand-header')),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF444444), size: 28),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '搜索账本或记录',
                      hintStyle: TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF232323),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: '我的收礼',
                  subtitle: '人情',
                  iconAsset: 'home design1/1.png',
                  active: _activeType == GiftRecordType.received,
                  onTap: () => _switchLedgerType(GiftRecordType.received),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  title: '我的回礼',
                  subtitle: '往来',
                  iconAsset: 'home design1/2.png',
                  active: _activeType == GiftRecordType.returned,
                  onTap: () => _switchLedgerType(GiftRecordType.returned),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: records.isEmpty
                ? _EmptyListView(type: _activeType)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 116),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final contact = _contactById(record.contactId);
                      if (contact == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Slidable(
                          key: ValueKey(record.id),
                          closeOnScroll: true,
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.22,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _tryDeleteRecord(record),
                                backgroundColor: const Color(0xFFFF3137),
                                foregroundColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                spacing: 0,
                                icon: Icons.delete_outline_rounded,
                                autoClose: true,
                              ),
                            ],
                          ),
                          child: _RecordCard(
                            record: record,
                            contact: contact,
                            onTap: () => _showTicketDialog(record, contact),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipTabBody() {
    final grouped = <RelationGroup, List<ContactProfile>>{
      for (final group in RelationGroup.values) group: <ContactProfile>[],
    };
    for (final contact in _contacts) {
      grouped[contact.group]!.add(contact);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final netCompare = _netForContact(b.id).compareTo(_netForContact(a.id));
        if (netCompare != 0) return netCompare;
        return a.name.compareTo(b.name);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Image.asset('relation/4.png', height: 28, fit: BoxFit.contain),
                const Spacer(),
                IconButton(
                  onPressed: _openAddContactSheet,
                  icon: const Icon(
                    Icons.add_circle,
                    color: Color(0xFFFA636B),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 116),
              itemCount: RelationGroup.values.length,
              itemBuilder: (context, index) {
                final group = RelationGroup.values[index];
                final contacts = grouped[group]!;
                final expanded = _groupExpanded[group] ?? true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GroupSection(
                    group: group,
                    contacts: contacts,
                    expanded: expanded,
                    onToggle: () {
                      setState(() {
                        _groupExpanded[group] = !expanded;
                      });
                    },
                    netAmountOfContact: (contactId) =>
                        _netForContact(contactId),
                    onTapContact: _openContactDetail,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddedTabBody() {
    return _AddRecordTabBody(
      contacts: _contacts,
      onBackHome: () {
        if (_activeBottomTab == BottomTabType.home) return;
        setState(() {
          _activeBottomTab = BottomTabType.home;
        });
      },
      onCreateRecord: (contactName, group, draft) => _createRecordFromAddTab(
        contactName: contactName,
        group: group,
        draft: draft,
      ),
    );
  }

  DateTime get _statsReferenceDate {
    if (_records.isEmpty) return DateTime.now();
    var latest = _records.first.date;
    for (final record in _records.skip(1)) {
      if (record.date.isAfter(latest)) {
        latest = record.date;
      }
    }
    return latest;
  }

  Widget _buildStatsTabBody() {
    return _StatsTabBody(
      records: _records,
      contacts: _contacts,
      period: _activeStatsPeriod,
      referenceDate: _statsReferenceDate,
      onPeriodChanged: (period) {
        setState(() {
          _activeStatsPeriod = period;
        });
      },
    );
  }

  Widget _buildCalendarTabBody() {
    return _CalendarTabBody(
      entries: _calendarEntries,
      onCreateEntry: _createCalendarEntry,
      onUpdateEntry: _updateCalendarEntry,
      onDeleteEntry: _deleteCalendarEntry,
      onOpenSettings: _openSettingsPage,
    );
  }

  Widget _buildPlaceholderTabBody(String title) {
    return Center(
      child: Text(
        '$title 开发中',
        style: const TextStyle(
          color: Color(0xAA4B4B4B),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildBodyByTab() {
    if (_activeBottomTab == BottomTabType.calendar) {
      return _buildCalendarTabBody();
    }

    switch (_activeBottomTab) {
      case BottomTabType.home:
        return _buildHomeTabBody(_filteredRecords);
      case BottomTabType.relationship:
        return _buildRelationshipTabBody();
      case BottomTabType.added:
        return _buildAddedTabBody();
      case BottomTabType.data:
        return _buildStatsTabBody();
      case BottomTabType.calendar:
        return _buildPlaceholderTabBody('日历');
    }
  }

  void _showTicketDialog(GiftRecord record, ContactProfile contact) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ticket_detail_dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: _GiftTicketDialog(record: record, contact: contact),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabBody = _buildBodyByTab();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('bg.png', fit: BoxFit.cover),
          if (_activeBottomTab == BottomTabType.added)
            tabBody
          else
            SafeArea(child: tabBody),
          if (_activeBottomTab != BottomTabType.added)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomTabBar(
                imageAsset: _bottomTabImageAsset,
                onTap: _onBottomTabTap,
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialRemindersEnabled,
    required this.onReminderChanged,
  });

  final bool initialRemindersEnabled;
  final Future<void> Function(bool enabled) onReminderChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _remindersEnabled = false;

  String get _reminderSubtitle {
    return _remindersEnabled ? '已开启，后续记录提醒会使用此开关' : '关闭后不接收记录提醒';
  }

  @override
  void initState() {
    super.initState();
    _remindersEnabled = widget.initialRemindersEnabled;
    _loadReminderSetting();
  }

  Future<void> _loadReminderSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _remindersEnabled = prefs.getBool(kReminderEnabledKey) ?? false;
    });
  }

  Future<void> _setRemindersEnabled(bool value) async {
    setState(() {
      _remindersEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kReminderEnabledKey, value);
    await widget.onReminderChanged(value);
  }

  void _openDetail(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsDetailPage(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111111),
            size: 24,
          ),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            _SettingsSwitchRow(
              icon: Icons.notifications_none_rounded,
              title: '提醒通知',
              subtitle: _reminderSubtitle,
              value: _remindersEnabled,
              onChanged: _setRemindersEnabled,
            ),
            _SettingsRow(
              icon: Icons.shield_outlined,
              title: '隐私政策',
              onTap: () => _openDetail('隐私政策', _privacyPolicyText),
            ),
            _SettingsRow(
              icon: Icons.description_outlined,
              title: '用户协议',
              onTap: () => _openDetail('用户协议', _userAgreementText),
            ),
            _SettingsRow(
              icon: Icons.info_outline_rounded,
              title: '关于我们',
              onTap: () => _openDetail('关于我们', _aboutUsText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFC1C1C1), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF111111), size: 32),
            const SizedBox(width: 22),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF111111),
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFC1C1C1), width: 1),
          bottom: BorderSide(color: Color(0xFFC1C1C1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF111111), size: 32),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6E6E73),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFFA636B),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111111),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Text(
            body,
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 16,
              height: 1.7,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

const String _privacyPolicyText = '''
隐私政策（礼小记）

最后更新日期：2026.5.18 
生效日期：2026.5.20

前言
感谢您使用礼小记。  
「礼小记」（以下简称“本应用”或“我们”）是指由礼小记团队合法拥有并运营的移动应用产品及相关功能服务。  
我们非常重视您的个人信息和隐私保护。在您使用本应用前，请您认真阅读并充分理解本隐私政策；您开始使用本应用，即表示您已同意本隐私政策的内容。若您不同意本政策的任何内容，请停止使用本应用。

本政策将帮助您了解以下内容：  
一、我们收集哪些信息，以及如何收集和使用这些信息；  
二、权限说明；  
三、我们如何存储和保护您的信息；  
四、您如何管理您的信息；  
五、本隐私政策的更新与通知。

---

一、我们收集哪些信息，以及如何收集和使用您的个人信息
礼小记尊重并保护您的隐私。当前版本下，我们遵循“最小必要”原则处理信息：

1. 本地记录数据  
您在应用内主动录入的内容（如联系人名称、关系标签、收礼/回礼记录、金额、日期、备注、日历记录等）仅保存在您的设备本地，用于实现记账、统计与日历管理功能。

2. 无账号体系  
礼小记当前不提供账号注册与登录功能，因此我们不会主动收集您的手机号、邮箱、身份证号等账号身份信息。

3. 不主动上传  
在当前版本中，您的主要业务数据不会被我们主动上传至我们的服务器，也不会用于广告推荐或对外出售。

---

二、权限说明
我们仅在您使用对应功能时申请必要权限，并在获得您授权后使用：

1. 通知权限（可选）  
当您开启“提醒通知”功能时，应用可能申请系统通知权限，用于向您发送本地提醒。  
若您拒绝授权，提醒功能可能无法正常使用，但不影响其他核心功能。

2. 其他权限  
当前版本不强制申请与核心功能无关的敏感权限。若未来新增功能需要额外权限（如相机、相册等），我们会在功能触发时单独征求您的同意，并在本政策中更新说明。

3. 撤回授权  
您可随时在手机系统设置中关闭已授权权限。关闭后，相关功能可能受限或不可用。

---

三、我们如何保留、存储和保护您的个人信息安全
1. 本地存储  
您的业务数据默认保存在设备本地存储空间中。

2. 安全措施  
我们会持续采取合理技术措施降低数据被未经授权访问、披露或篡改的风险。

3. 数据恢复说明  
您在本地删除的数据通常无法由我们恢复；卸载应用、清除应用数据等操作可能导致数据永久丢失，请谨慎操作。

---

四、如何管理您的个人信息
1. 查看和修改  
您可在应用内查看、编辑和删除已录入的记录信息。

2. 删除数据  
您可通过应用内删除操作清理部分或全部记录；也可通过系统设置清除应用数据。

3. 权限管理  
您可通过手机系统设置随时管理通知等权限状态。

---

五、隐私政策的通知和修订
1. 我们可能根据产品功能变化或法律法规要求对本政策进行更新。  
2. 如发生重大变更，我们将通过应用内显著方式提示。  
3. 若您不同意更新后的政策内容，您可停止使用本应用；您继续使用即视为接受更新后的政策。  
4. 建议您定期查阅本隐私政策，以了解最新版本。  
5. 如您对本政策有疑问、意见或建议，请通过以下方式联系我们：  
联系邮箱：1447983695@qq.com
我们将在15个工作日内回复。 

---
''';

const String _userAgreementText = '''
《用户协议》
最后更新日期：2026.5.18
生效日期：2026.5.20

重要须知
请您务必审慎阅读并充分理解以下内容，同意本协议后方可使用本应用：

数据存储与风险：您在礼小记中输入的联系人、往来记录、日历记录等数据仅存储在您的设备本地。卸载应用、清除应用数据或更换设备，可能导致数据永久丢失，相关风险由您自行承担。
功能局限性：礼小记提供的记录、统计、提醒等功能仅供个人管理参考，不构成财务、法律或其他专业建议。
权限必要性：当您使用提醒通知功能时，应用可能申请通知权限；若您拒绝授权，对应功能可能无法使用，但不影响其他核心功能。
未成年人使用：若您未满14周岁，应在监护人指导下使用本应用，监护人应承担相应管理责任。
协议更新约束：我们可能依法更新本协议。您继续使用本应用，视为接受更新后的协议；若您不同意，应停止使用。
一、开发者与协议接受
开发者信息：本应用由开发并运营。
接受方式：您点击同意、下载、安装或使用本应用，即视为已阅读并接受本协议及《隐私政策》。
二、服务内容
核心功能：礼小记提供收礼/回礼记录、关系管理、统计展示、日历记录与提醒设置等功能。
本地化使用：当前版本主要功能基于本地数据运行，不依赖账号登录。
服务调整：我们可根据产品迭代对功能进行优化、调整或下线，并以合理方式通知。
三、用户义务
合法使用：您承诺合法使用本应用，不利用本应用从事违法违规活动。
内容责任：您自行对录入内容的真实性、合法性、完整性负责，不得录入侵犯他人权益或违法违规的信息。
账号设备安全：您应妥善保管个人设备，因设备丢失、系统故障、误操作导致的数据风险由您自行承担。
四、数据与权限
数据存储：您的业务数据默认存储于设备本地。
权限申请：我们仅在必要场景申请系统权限，并在系统弹窗中说明用途。
授权撤回：您可随时在系统设置中关闭权限，关闭后对应功能可能受限。
五、免责声明
参考性质：应用中的统计结果、提醒信息仅作参考，不保证绝对准确或及时。
风险承担：因您依赖应用记录、提醒或统计结果而产生的直接或间接损失，由您自行承担。
不可抗力：因不可抗力、系统故障、设备异常、第三方服务异常等导致的服务中断或数据问题，我们在法律允许范围内免责。
六、知识产权
应用权属：礼小记的代码、界面设计、标识及相关知识产权归开发者所有。
用户内容：您对自行录入内容依法享有权利；您授权我们在提供本应用功能所必需范围内进行处理。
禁止行为：未经许可，不得对本应用进行反向工程、反编译、破解或制作衍生版本。
七、服务终止
若您违反法律法规或本协议，我们有权在必要时限制或终止向您提供服务。
服务终止后，除法律另有规定外，我们不承担额外补偿责任。
八、其他条款
法律适用：法律适用‌：本协议受中国大陆法律管辖，争议提交‌[湖南省株洲市]‌人民法院诉讼解决。
争议解决：因本协议引起的争议，双方应先协商；协商不成的，提交有管辖权的人民法院解决。
协议更新：更新后的协议将在应用内公示并于公示期后生效。
联系方式：联系邮箱1447983695@qq.com，我们将在15个工作日内回复。
''';

const String _aboutUsText = '''
礼小记

一个帮助你记录人情往来、礼金收支和重要日历事项的小工具。

当前版本：1.0.0

我们希望它简单、清楚、好用，让每一次往来都有迹可循。
''';

const List<Color> _statsPalette = [
  Color(0xFFFF545D),
  Color(0xFFBFC2C8),
  Color(0xFFFFC69E),
  Color(0xFFFFD25E),
  Color(0xFF74B6A8),
  Color(0xFF979AAC),
];

class _StatsDistributionItem {
  const _StatsDistributionItem({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String label;
  final int amount;
  final double percent;
  final Color color;
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.amount});

  final String label;
  final int amount;
}

class _StatsTabBody extends StatelessWidget {
  const _StatsTabBody({
    required this.records,
    required this.contacts,
    required this.period,
    required this.referenceDate,
    required this.onPeriodChanged,
  });

  final List<GiftRecord> records;
  final List<ContactProfile> contacts;
  final _StatsPeriod period;
  final DateTime referenceDate;
  final ValueChanged<_StatsPeriod> onPeriodChanged;

  List<GiftRecord> _recordsForPeriod() {
    return records.where((record) {
      switch (period) {
        case _StatsPeriod.month:
          return record.date.year == referenceDate.year &&
              record.date.month == referenceDate.month;
        case _StatsPeriod.year:
          return record.date.year == referenceDate.year;
        case _StatsPeriod.all:
          return true;
      }
    }).toList();
  }

  List<_StatsDistributionItem> _buildDistribution(List<GiftRecord> source) {
    final contactById = {for (final contact in contacts) contact.id: contact};
    final totals = <RelationGroup, int>{};

    for (final record in source) {
      final contact = contactById[record.contactId];
      if (contact == null) continue;
      totals[contact.group] = (totals[contact.group] ?? 0) + record.amount;
    }

    final entries = totals.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return [
      for (var i = 0; i < entries.length; i++)
        _StatsDistributionItem(
          label: entries[i].key.label,
          amount: entries[i].value,
          percent: total == 0 ? 0 : entries[i].value / total,
          color: _statsPalette[i % _statsPalette.length],
        ),
    ];
  }

  List<_TrendPoint> _buildTrendPoints() {
    final start = DateTime(referenceDate.year, referenceDate.month - 5);
    return [
      for (var i = 0; i < 6; i++)
        _TrendPoint(
          label: '${DateTime(start.year, start.month + i).month}月',
          amount: records.fold<int>(0, (sum, record) {
            final month = DateTime(start.year, start.month + i);
            if (record.date.year == month.year &&
                record.date.month == month.month) {
              return sum + record.amount;
            }
            return sum;
          }),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final periodRecords = _recordsForPeriod();
    var income = 0;
    var expense = 0;
    for (final record in periodRecords) {
      if (record.type == GiftRecordType.received) {
        income += record.amount;
      } else {
        expense += record.amount;
      }
    }

    final distribution = _buildDistribution(periodRecords);
    final totalAmount = income + expense;
    final trendPoints = _buildTrendPoints();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'relation/5.png',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _StatsSegmentedControl(
            activePeriod: period,
            onChanged: onPeriodChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 116),
              children: [
                _StatsOverviewCard(
                  period: period,
                  income: income,
                  expense: expense,
                ),
                const SizedBox(height: 16),
                _StatsDistributionCard(
                  items: distribution,
                  totalAmount: totalAmount,
                ),
                const SizedBox(height: 16),
                _StatsTrendCard(points: trendPoints),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSegmentedControl extends StatelessWidget {
  const _StatsSegmentedControl({
    required this.activePeriod,
    required this.onChanged,
  });

  final _StatsPeriod activePeriod;
  final ValueChanged<_StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
      ),
      child: Row(
        children: [
          for (final item in _StatsPeriod.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activePeriod == item
                        ? const Color(0xFFFF545D)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: activePeriod == item
                          ? Colors.white
                          : const Color(0xFF9B9BA2),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsOverviewCard extends StatelessWidget {
  const _StatsOverviewCard({
    required this.period,
    required this.income,
    required this.expense,
  });

  final _StatsPeriod period;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -26,
            child: Icon(
              Icons.favorite_rounded,
              size: 128,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.overviewTitle,
                style: const TextStyle(
                  color: Color(0xFF53535B),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _StatsAmountMetric(value: '+$income', label: '收入'),
                  ),
                  Container(
                    width: 1,
                    height: 56,
                    color: const Color(0xFFEEC2C7),
                  ),
                  Expanded(
                    child: _StatsAmountMetric(value: '-$expense', label: '支出'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsAmountMetric extends StatelessWidget {
  const _StatsAmountMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFFF4F59),
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E7F84),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatsDistributionCard extends StatelessWidget {
  const _StatsDistributionCard({
    required this.items,
    required this.totalAmount,
  });

  final List<_StatsDistributionItem> items;
  final int totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关系分布',
            style: TextStyle(
              color: Color(0xFF202024),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const _StatsEmptyPanel()
          else
            Row(
              children: [
                _StatsDonutChart(items: items, totalAmount: totalAmount),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    children: [
                      for (final item in items) _StatsLegendRow(item: item),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatsDonutChart extends StatelessWidget {
  const _StatsDonutChart({required this.items, required this.totalAmount});

  final List<_StatsDistributionItem> items;
  final int totalAmount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(132),
            painter: _StatsDonutPainter(items: items),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '总计',
                style: TextStyle(
                  color: Color(0xFFC8C8CE),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$totalAmount',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFB3B3BA),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsDonutPainter extends CustomPainter {
  const _StatsDonutPainter({required this.items});

  final List<_StatsDistributionItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (math.min(size.width, size.height) - strokeWidth) / 2,
    );
    final basePaint = Paint()
      ..color = const Color(0xFFE4E4E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);
    if (items.isEmpty) return;

    var startAngle = -math.pi / 2;
    for (final item in items) {
      final sweep = item.percent * math.pi * 2;
      final gap = items.length > 1 ? 0.028 : 0.0;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, math.max(0, sweep - gap), false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StatsDonutPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

class _StatsLegendRow extends StatelessWidget {
  const _StatsLegendRow({required this.item});

  final _StatsDistributionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8B8B92),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${(item.percent * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFF62626B),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTrendCard extends StatelessWidget {
  const _StatsTrendCard({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '趋势图',
            style: TextStyle(
              color: Color(0xFF202024),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _StatsTrendChart(points: points),
        ],
      ),
    );
  }
}

class _StatsTrendChart extends StatelessWidget {
  const _StatsTrendChart({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      child: CustomPaint(
        painter: _StatsTrendPainter(points: points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StatsTrendPainter extends CustomPainter {
  const _StatsTrendPainter({required this.points});

  final List<_TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(34, 8, size.width - 42, size.height - 36);
    final rawMax = points.fold<int>(
      0,
      (maxValue, point) => point.amount > maxValue ? point.amount : maxValue,
    );
    final maxValue = rawMax <= 0 ? 1 : rawMax;
    final gridPaint = Paint()
      ..color = const Color(0xFFF0DDE0)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFE1E1E6)
      ..strokeWidth = 1.2;

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final labelValue = (maxValue * (3 - i) / 3).round();
      _drawCanvasText(
        canvas,
        _formatStatsAxisValue(labelValue),
        Offset(0, y - 8),
        const TextStyle(
          color: Color(0xFFD7D7DD),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    if (points.isEmpty) return;

    final offsets = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(
          chartRect.left +
              (points.length == 1
                  ? chartRect.width / 2
                  : chartRect.width * i / (points.length - 1)),
          chartRect.bottom - chartRect.height * points[i].amount / maxValue,
        ),
    ];
    final linePath = _buildSmoothPath(offsets);
    final areaPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, chartRect.bottom)
      ..lineTo(offsets.first.dx, chartRect.bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33FF5B64), Color(0x00FF5B64)],
      ).createShader(chartRect);
    final linePaint = Paint()
      ..color = const Color(0xFFFF8A91)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = const Color(0xFFFF5B64);
    final dotHaloPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);

    canvas.drawPath(areaPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
    for (final offset in offsets) {
      canvas.drawCircle(offset, 5, dotHaloPaint);
      canvas.drawCircle(offset, 3, dotPaint);
    }

    for (var i = 0; i < points.length; i++) {
      _drawCanvasText(
        canvas,
        points[i].label,
        Offset(offsets[i].dx, chartRect.bottom + 12),
        const TextStyle(
          color: Color(0xFFC7C7CD),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        centered: true,
      );
    }
  }

  Path _buildSmoothPath(List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  void _drawCanvasText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final paintOffset = centered
        ? Offset(offset.dx - painter.width / 2, offset.dy)
        : offset;
    painter.paint(canvas, paintOffset);
  }

  @override
  bool shouldRepaint(covariant _StatsTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _StatsEmptyPanel extends StatelessWidget {
  const _StatsEmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 132,
      child: Center(
        child: Text(
          '暂无统计数据',
          style: TextStyle(
            color: Color(0xFFC4C4CB),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CalendarTabBody extends StatefulWidget {
  const _CalendarTabBody({
    required this.entries,
    required this.onCreateEntry,
    required this.onUpdateEntry,
    required this.onDeleteEntry,
    required this.onOpenSettings,
  });

  final List<CalendarEntry> entries;
  final ValueChanged<CalendarEntryDraft> onCreateEntry;
  final void Function(CalendarEntry entry, CalendarEntryDraft draft)
  onUpdateEntry;
  final ValueChanged<CalendarEntry> onDeleteEntry;
  final VoidCallback onOpenSettings;

  @override
  State<_CalendarTabBody> createState() => _CalendarTabBodyState();
}

class _CalendarTabBodyState extends State<_CalendarTabBody> {
  static const List<String> _weekdayLabels = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final initial = _resolveInitialDate();
    _focusedMonth = DateTime(initial.year, initial.month);
    _selectedDay = _dayOnly(initial);
  }

  DateTime _resolveInitialDate() {
    if (widget.entries.isEmpty) return DateTime.now();
    var latest = widget.entries.first.dateTime;
    for (final entry in widget.entries.skip(1)) {
      if (entry.dateTime.isAfter(latest)) {
        latest = entry.dateTime;
      }
    }
    return latest;
  }

  DateTime _dayOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<CalendarEntry> get _selectedEntries {
    final selected = widget.entries.where((entry) {
      return _isSameDay(entry.dateTime, _selectedDay);
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return selected;
  }

  bool _hasEntryOnDay(DateTime day) {
    for (final entry in widget.entries) {
      if (_isSameDay(entry.dateTime, day)) return true;
    }
    return false;
  }

  List<DateTime> get _monthGridDays {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final offsetFromMonday = firstOfMonth.weekday - DateTime.monday;
    final gridStart = firstOfMonth.subtract(Duration(days: offsetFromMonday));
    return List.generate(42, (index) => gridStart.add(Duration(days: index)));
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = _dayOnly(day);
      _focusedMonth = DateTime(day.year, day.month);
    });
  }

  Future<void> _openCreateSheet() async {
    final now = DateTime.now();
    final initialDateTime = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      now.hour,
      now.minute,
    );
    final result = await showModalBottomSheet<_CalendarEntryEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) {
        return _CalendarEntryEditorSheet(initialDateTime: initialDateTime);
      },
    );
    final draft = result?.draft;
    if (draft == null || !mounted) return;
    widget.onCreateEntry(draft);
    setState(() {
      _focusedMonth = DateTime(draft.dateTime.year, draft.dateTime.month);
      _selectedDay = _dayOnly(draft.dateTime);
    });
  }

  Future<void> _openEditSheet(CalendarEntry entry) async {
    final result = await showModalBottomSheet<_CalendarEntryEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) {
        return _CalendarEntryEditorSheet(
          initialDateTime: entry.dateTime,
          initialEntry: entry,
        );
      },
    );
    if (result == null || !mounted) return;
    if (result.shouldDelete) {
      widget.onDeleteEntry(entry);
      return;
    }
    final draft = result.draft;
    if (draft == null) return;
    widget.onUpdateEntry(entry, draft);
    setState(() {
      _focusedMonth = DateTime(draft.dateTime.year, draft.dateTime.month);
      _selectedDay = _dayOnly(draft.dateTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntries = _selectedEntries;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Image.asset('relation/6.png', height: 28, fit: BoxFit.contain),
                const Spacer(),
                IconButton(
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFFFA636B),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _goToPreviousMonth,
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF7B7B83),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Color(0xFF1F1F24),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _goToNextMonth,
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF7B7B83),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    for (final label in _weekdayLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9AA2),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _monthGridDays.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final day = _monthGridDays[index];
                    final isCurrentMonth =
                        day.year == _focusedMonth.year &&
                        day.month == _focusedMonth.month;
                    final isSelected = _isSameDay(day, _selectedDay);
                    final hasEntry = _hasEntryOnDay(day);
                    return GestureDetector(
                      onTap: () => _selectDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF6269)
                              : isCurrentMonth
                              ? const Color(0xFFFFFCFD)
                              : const Color(0xFFF3F3F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasEntry && !isSelected
                                ? const Color(0xFFFFD3D8)
                                : Colors.transparent,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isCurrentMonth
                                    ? const Color(0xFF34343A)
                                    : const Color(0xFFB4B4BC),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (hasEntry)
                              Positioned(
                                right: 5,
                                top: 5,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFFF6D75),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _formatDate(_selectedDay),
                style: const TextStyle(
                  color: Color(0xFF1F1F24),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${selectedEntries.length} 条',
                style: const TextStyle(
                  color: Color(0xFF9A9AA2),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openCreateSheet,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFA636B),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  '添加',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: selectedEntries.isEmpty
                ? const _CalendarEmptyPanel()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 116),
                    itemCount: selectedEntries.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CalendarEntryCard(
                          entry: selectedEntries[index],
                          onTap: () => _openEditSheet(selectedEntries[index]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEmptyPanel extends StatelessWidget {
  const _CalendarEmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_note_rounded,
            size: 76,
            color: Color(0xFFE3E3E8),
          ),
          const SizedBox(height: 8),
          const Text(
            '当天还没有记录',
            style: TextStyle(
              color: Color(0xFF9A9AA1),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEntryCard extends StatelessWidget {
  const _CalendarEntryCard({required this.entry, required this.onTap});

  final CalendarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE3E6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF25252C),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(entry.dateTime),
                    style: const TextStyle(
                      color: Color(0xFFFA636B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '人物：${entry.person}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F6F79),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  entry.note,
                  style: const TextStyle(
                    color: Color(0xFF52525A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEntryEditorSheet extends StatefulWidget {
  const _CalendarEntryEditorSheet({
    required this.initialDateTime,
    this.initialEntry,
  });

  final DateTime initialDateTime;
  final CalendarEntry? initialEntry;

  @override
  State<_CalendarEntryEditorSheet> createState() =>
      _CalendarEntryEditorSheetState();
}

class _CalendarEntryEditorSheetState extends State<_CalendarEntryEditorSheet> {
  late final TextEditingController _personController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _personController = TextEditingController(
      text: widget.initialEntry?.person,
    );
    _titleController = TextEditingController(text: widget.initialEntry?.title);
    _noteController = TextEditingController(text: widget.initialEntry?.note);
    _selectedDateTime = widget.initialDateTime;
  }

  @override
  void dispose() {
    _personController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    const themeRed = Color(0xFFF12530);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: themeRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              surfaceContainerHighest: Colors.white,
              surfaceContainerHigh: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return themeRed;
                return null;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return themeRed;
              }),
              todayBorder: const BorderSide(color: themeRed),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return themeRed;
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    const themeRed = Color(0xFFF12530);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: themeRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              surfaceContainerHighest: Colors.white,
              surfaceContainerHigh: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialBackgroundColor: Colors.white,
              hourMinuteColor: Colors.white,
              dayPeriodColor: Colors.white,
              entryModeIconColor: themeRed,
              dialHandColor: themeRed,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _save() {
    final person = _personController.text.trim();
    final title = _titleController.text.trim();
    if (person.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写人物')));
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写标题')));
      return;
    }
    Navigator.of(context).pop(
      _CalendarEntryEditorResult.save(
        CalendarEntryDraft(
          dateTime: _selectedDateTime,
          person: person,
          title: title,
          note: _noteController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('删除这条记录？'),
          content: const Text('删除后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || !mounted) return;
    Navigator.of(context).pop(const _CalendarEntryEditorResult.delete());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = math.max(0.0, MediaQuery.viewInsetsOf(context).bottom);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    widget.initialEntry == null ? '添加日历记录' : '编辑日历记录',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '时间',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF353535),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _CalendarPickerField(
                        value: _formatDate(_selectedDateTime),
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: _CalendarPickerField(
                        value: _formatTime(_selectedDateTime),
                        icon: Icons.schedule_rounded,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _LabeledInput(
                  label: '人物',
                  child: TextField(
                    controller: _personController,
                    decoration: const InputDecoration(hintText: '输入人物姓名'),
                  ),
                ),
                const SizedBox(height: 10),
                _LabeledInput(
                  label: '标题',
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(hintText: '输入标题'),
                  ),
                ),
                const SizedBox(height: 10),
                _LabeledInput(
                  label: '备注',
                  child: TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '输入备注（可选）'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFA636B),
                    ),
                    child: Text(
                      widget.initialEntry == null ? '保存' : '保存修改',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (widget.initialEntry != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                      ),
                      child: const Text(
                        '删除记录',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarPickerField extends StatelessWidget {
  const _CalendarPickerField({
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E6EB)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF9B9BA4)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF323239),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.imageAsset, required this.onTap});

  final String imageAsset;
  final ValueChanged<BottomTabType> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: Image.asset(imageAsset, fit: BoxFit.contain),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < BottomTabType.values.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(BottomTabType.values[i]),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image(
          image: AssetImage('home design1/4.png'),
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _AddRecordTabBody extends StatefulWidget {
  const _AddRecordTabBody({
    required this.contacts,
    required this.onBackHome,
    required this.onCreateRecord,
  });

  final List<ContactProfile> contacts;
  final VoidCallback onBackHome;
  final void Function(
    String contactName,
    RelationGroup group,
    RecordDraft draft,
  )
  onCreateRecord;

  @override
  State<_AddRecordTabBody> createState() => _AddRecordTabBodyState();
}

class _AddRecordTabBodyState extends State<_AddRecordTabBody> {
  static const List<int> _quickAmounts = [200, 500, 800];
  static const List<String> _tagOptions = [
    '朋友',
    '同事',
    '家人',
    '客户',
    '同学',
    '亲戚',
    '邻居',
    '自定义',
  ];
  static const List<String> _occasionOptions = [
    '生日',
    '婚礼',
    '乔迁',
    '升学宴',
    '满月',
    '新居',
    '节日',
  ];

  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _customTagController;
  late final FocusNode _amountFocusNode;

  GiftRecordType _type = GiftRecordType.received;
  int? _selectedQuickAmount = 800;
  String? _selectedTag;
  DateTime? _selectedDate;
  String? _selectedOccasion;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '1000');
    _nameController = TextEditingController();
    _noteController = TextEditingController();
    _customTagController = TextEditingController();
    _amountFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    _customTagController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    const themeRed = Color(0xFFF12530);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: themeRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              surfaceContainerHighest: Colors.white,
              surfaceContainerHigh: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return themeRed;
                return null;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return themeRed;
              }),
              todayBorder: const BorderSide(color: themeRed),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return themeRed;
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickOccasion() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1E1E5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final option in _occasionOptions)
                    ListTile(
                      title: Text(
                        option,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: _selectedOccasion == option
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFFFF5F66),
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _selectedOccasion = picked;
    });
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _selectedQuickAmount = amount;
      _amountController.text = amount.toString();
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
    });
  }

  void _selectCustomAmount() {
    setState(() {
      _selectedQuickAmount = null;
    });
    _amountFocusNode.requestFocus();
    _amountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amountController.text.length,
    );
  }

  void _onAmountChanged(String value) {
    final parsed = int.tryParse(value.trim());
    final matched = _quickAmounts.contains(parsed) ? parsed : null;
    if (_selectedQuickAmount == matched) return;
    setState(() {
      _selectedQuickAmount = matched;
    });
  }

  void _selectTag(String tag) {
    setState(() {
      _selectedTag = tag;
      if (tag != '自定义') {
        _customTagController.clear();
      }
    });
  }

  RelationGroup _mapTagToGroup(String tag) {
    switch (tag) {
      case '朋友':
        return RelationGroup.friend;
      case '同学':
        return RelationGroup.classmate;
      case '同事':
        return RelationGroup.colleague;
      case '亲戚':
      case '家人':
        return RelationGroup.relative;
      case '邻居':
        return RelationGroup.neighbor;
      case '客户':
      case '自定义':
        return RelationGroup.other;
    }
    return RelationGroup.other;
  }

  void _save() {
    final amount = int.tryParse(_amountController.text.trim());
    final name = _nameController.text.trim();
    final selectedTag = _selectedTag;
    final customTag = _customTagController.text.trim();
    final date = _selectedDate;
    final occasion = _selectedOccasion;
    if (amount == null || amount <= 0) {
      _showError('请填写有效金额');
      return;
    }
    if (name.isEmpty) {
      _showError('请填写姓名');
      return;
    }
    if (selectedTag == null) {
      _showError('请选择标签');
      return;
    }
    if (selectedTag == '自定义' && customTag.isEmpty) {
      _showError('请输入自定义标签');
      return;
    }
    if (selectedTag == '自定义' && customTag.runes.length > 4) {
      _showError('自定义标签最多4个字');
      return;
    }
    if (date == null) {
      _showError('请选择日期');
      return;
    }
    if (occasion == null) {
      _showError('请选择场景');
      return;
    }

    widget.onCreateRecord(
      name,
      _mapTagToGroup(selectedTag),
      RecordDraft(
        type: _type,
        amount: amount,
        date: date,
        occasion: occasion,
        note: _noteController.text.trim(),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final imageHeight = width * (7700 / 2997);
    final whitePanelTop = imageHeight * (1095 / 8547);
    final horizontalPadding = (width * 0.069).clamp(24.0, 36.0);
    final fieldHeight = width >= 420 ? 86.0 : 76.0;
    const knownNameHint = '请输入送礼或回礼人的姓名';

    final topInset = MediaQuery.paddingOf(context).top;
    final backLeft = math.max(horizontalPadding - 8, 16.0);
    final backTop = topInset + 14;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Stack(
                children: [
                  SizedBox(
                    width: width,
                    height: imageHeight,
                    child: Image.asset('add3/1.png', fit: BoxFit.fill),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      whitePanelTop + 16,
                      horizontalPadding,
                      30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 52),
                        Row(
                          children: [
                            Expanded(
                              child: _AddTypeButton(
                                title: '送礼',
                                active: _type == GiftRecordType.received,
                                onTap: () => setState(
                                  () => _type = GiftRecordType.received,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _AddTypeButton(
                                title: '回礼',
                                active: _type == GiftRecordType.returned,
                                onTap: () => setState(
                                  () => _type = GiftRecordType.returned,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 31),
                        const _AddRequiredLabel('金额'),
                        const SizedBox(height: 9),
                        Container(
                          height: fieldHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 23),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFD6D6DE),
                              width: 1.3,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '¥',
                                style: TextStyle(
                                  color: Color(0xFF3B3B43),
                                  fontSize: 40,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  focusNode: _amountFocusNode,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  onChanged: _onAmountChanged,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF3B3B43),
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 19),
                        Row(
                          children: [
                            for (final amount in _quickAmounts) ...[
                              Expanded(
                                child: _QuickAmountButton(
                                  label: '¥$amount',
                                  active: _selectedQuickAmount == amount,
                                  onTap: () => _selectQuickAmount(amount),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: _QuickAmountButton(
                                label: '自定义',
                                active: _selectedQuickAmount == null,
                                onTap: _selectCustomAmount,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 27),
                        const _AddRequiredLabel('姓名'),
                        const SizedBox(height: 10),
                        _AddTextField(
                          controller: _nameController,
                          hintText: knownNameHint,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 24),
                        const _AddRequiredLabel('标签'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final tag in _tagOptions)
                              SizedBox(
                                width: (width - horizontalPadding * 2 - 36) / 4,
                                child: _AddTagButton(
                                  label: tag,
                                  active: _selectedTag == tag,
                                  onTap: () => _selectTag(tag),
                                ),
                              ),
                          ],
                        ),
                        if (_selectedTag == '自定义') ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 57,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFB),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: TextField(
                              controller: _customTagController,
                              maxLength: 4,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                hintText: '请输入自定义名称不超过4个字',
                                hintStyle: TextStyle(
                                  color: Color(0xFFB8B8C2),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF2D2D33),
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const _AddRequiredLabel('日期'),
                        const SizedBox(height: 10),
                        _AddSelectField(
                          value: _selectedDate == null
                              ? null
                              : _formatDate(_selectedDate!),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 24),
                        const _AddRequiredLabel('场景'),
                        const SizedBox(height: 10),
                        _AddSelectField(
                          value: _selectedOccasion,
                          onTap: _pickOccasion,
                        ),
                        const SizedBox(height: 24),
                        const _AddRequiredLabel('备注'),
                        const SizedBox(height: 10),
                        _AddTextField(
                          controller: _noteController,
                          hintText: '想一下您当时送礼或收礼的场景~',
                          minLines: 4,
                          maxLines: 4,
                          height: 118,
                          textInputAction: TextInputAction.newline,
                        ),
                        const SizedBox(height: 38),
                        SizedBox(
                          width: double.infinity,
                          height: 59,
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFFFF6269),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '保存',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: backLeft,
            top: backTop,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.onBackHome,
                  child: Center(
                    child: Image.asset(
                      'add3/2.png',
                      width: 18,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTypeButton extends StatelessWidget {
  const _AddTypeButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF7F7) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFFFF6269) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF26262B),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFE5E5) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? const Color(0xFFFF7479) : Colors.transparent,
            width: 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFFF3139) : const Color(0xFF414149),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFE5E5) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? const Color(0xFFFF7479) : Colors.transparent,
            width: 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFFF3139) : const Color(0xFF414149),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRequiredLabel extends StatelessWidget {
  const _AddRequiredLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFFF6269)),
          ),
        ],
      ),
      style: const TextStyle(
        color: Color(0xFF1E1E22),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AddTextField extends StatelessWidget {
  const _AddTextField({
    required this.controller,
    required this.hintText,
    this.height = 57,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;
  final double height;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFB8B8C2),
            fontSize: 19,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: const TextStyle(
          color: Color(0xFF2D2D33),
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddSelectField extends StatelessWidget {
  const _AddSelectField({required this.value, required this.onTap});

  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 57,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const Spacer(),
            Text(
              value ?? '请选择',
              style: TextStyle(
                color: value == null
                    ? const Color(0xFFB8B8C2)
                    : const Color(0xFF2D2D33),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB8B8C2),
              size: 25,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFFEF6B72) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(iconAsset, width: 54, height: 54, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.contact,
    required this.onTap,
  });

  final GiftRecord record;
  final ContactProfile contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prefix = record.type == GiftRecordType.received ? '收到' : '送出';
    final sign = record.type == GiftRecordType.received ? '+' : '-';
    final partyLine = record.type == GiftRecordType.received
        ? '来自 ${contact.name}'
        : '送给 ${contact.name}';
    final amountColor = record.type == GiftRecordType.received
        ? const Color(0xFF111111)
        : const Color(0xFFFA5F68);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: AssetImage(
                record.type == GiftRecordType.received
                    ? 'home design1/3.png'
                    : 'home design1/5.png',
              ),
              fit: BoxFit.fill,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 66,
                right: 120,
                top: 12,
                child: Text(
                  partyLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFA1A1AA),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 120,
                bottom: 14,
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$prefix ',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFA1A1AA),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '$sign${record.amount}',
                        style: TextStyle(
                          fontSize: 30,
                          height: 0.95,
                          color: amountColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 32,
                bottom: 14,
                child: Container(
                  width: 58,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    contact.group.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftTicketDialog extends StatelessWidget {
  const _GiftTicketDialog({required this.record, required this.contact});

  final GiftRecord record;
  final ContactProfile contact;

  @override
  Widget build(BuildContext context) {
    final title = record.type == GiftRecordType.received
        ? '来自 ${contact.name} 的收礼'
        : '送给 ${contact.name} 的回礼';
    final amountColor = record.type == GiftRecordType.received
        ? Colors.white
        : const Color(0xFFFA5F68);
    final signedText = record.type == GiftRecordType.received
        ? '+${record.amount}'
        : '-${record.amount}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AspectRatio(
          aspectRatio: 2498 / 3183,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;

              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset('home design1/6.png', fit: BoxFit.fill),
                  ),
                  Positioned(
                    left: w * 0.37,
                    right: w * 0.14,
                    top: h * 0.30,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: w * 0.049,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF141414),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.40,
                    right: w * 0.16,
                    top: h * 0.40,
                    child: Container(
                      height: h * 0.08,
                      alignment: Alignment.center,
                      color: Colors.black.withValues(alpha: 0),
                      child: Text(
                        signedText,
                        style: TextStyle(
                          color: amountColor,
                          fontSize: w * 0.065,
                          fontWeight: FontWeight.w800,
                          height: 0.5,
                        ),
                      ),
                    ),
                  ),
                  _buildField(
                    label: '关系',
                    value: contact.group.label,
                    lineY: h * 0.58,
                    left: w * 0.38,
                    right: w * 0.12,
                  ),
                  _buildField(
                    label: '场景',
                    value: record.occasion,
                    lineY: h * 0.64,
                    left: w * 0.38,
                    right: w * 0.12,
                  ),
                  _buildField(
                    label: '日期',
                    value: _formatDate(record.date),
                    lineY: h * 0.70,
                    left: w * 0.38,
                    right: w * 0.12,
                  ),
                  _buildField(
                    label: '备注',
                    value: record.note,
                    lineY: h * 0.77,
                    left: w * 0.38,
                    right: w * 0.12,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required double lineY,
    required double left,
    required double right,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: lineY - 14,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '$label ',
              style: const TextStyle(
                color: Color(0xFFFA6068),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3D3D3D),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListView extends StatelessWidget {
  const _EmptyListView({required this.type});

  final GiftRecordType type;

  @override
  Widget build(BuildContext context) {
    final cnText = type == GiftRecordType.received ? '暂无收礼记录' : '暂无回礼记录';
    final enText = type == GiftRecordType.received
        ? 'No gift-receiving records yet.'
        : 'No gift-giving records yet.';
    final iconAsset = type == GiftRecordType.received
        ? 'relation/3.png'
        : 'relation/2.png';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconAsset, width: 154, fit: BoxFit.contain),
          const SizedBox(height: 12),
          Text(
            cnText,
            style: TextStyle(
              fontSize: 32,
              color: Colors.black.withValues(alpha: 0.14),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            enText,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black.withValues(alpha: 0.12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.contacts,
    required this.expanded,
    required this.onToggle,
    required this.netAmountOfContact,
    required this.onTapContact,
  });

  final RelationGroup group;
  final List<ContactProfile> contacts;
  final bool expanded;
  final VoidCallback onToggle;
  final int Function(int contactId) netAmountOfContact;
  final ValueChanged<ContactProfile> onTapContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: const Color(0xFF303030),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.folder_open_rounded,
                    color: Color(0xFFFA6A73),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group.label,
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${contacts.length} 人',
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded && contacts.isNotEmpty) ...[
            for (var i = 0; i < contacts.length; i++)
              Column(
                children: [
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF3F3F3),
                    ),
                  ListTile(
                    onTap: () => onTapContact(contacts[i]),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFFFE5E8),
                      child: Text(
                        contacts[i].name.characters.first,
                        style: const TextStyle(
                          color: Color(0xFFEA606B),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      contacts[i].name,
                      style: const TextStyle(
                        color: Color(0xFF2A2A2A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      contacts[i].note.isEmpty ? '暂无备注' : contacts[i].note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8D8D8D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Text(
                      _formatSigned(netAmountOfContact(contacts[i].id)),
                      style: TextStyle(
                        color: netAmountOfContact(contacts[i].id) >= 0
                            ? const Color(0xFF222222)
                            : const Color(0xFFFA5F68),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class ContactDetailPage extends StatefulWidget {
  const ContactDetailPage({
    super.key,
    required this.contact,
    required this.groupLabel,
    required this.recordsForContact,
    required this.onCreateRecord,
    required this.onEditRecord,
    required this.onDeleteRecord,
    required this.onDeleteContact,
    required this.netAmount,
  });

  final ContactProfile contact;
  final String groupLabel;
  final List<GiftRecord> Function() recordsForContact;
  final void Function(RecordDraft draft) onCreateRecord;
  final void Function(GiftRecord record, RecordDraft draft) onEditRecord;
  final void Function(GiftRecord record) onDeleteRecord;
  final Future<bool> Function() onDeleteContact;
  final int Function() netAmount;

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  Future<void> _addRecord() async {
    final draft = await Navigator.of(context).push<RecordDraft>(
      MaterialPageRoute<RecordDraft>(builder: (_) => const RecordEditorPage()),
    );
    if (draft == null) return;
    widget.onCreateRecord(draft);
    if (mounted) setState(() {});
  }

  Future<void> _editRecord(GiftRecord record) async {
    final draft = await Navigator.of(context).push<RecordDraft>(
      MaterialPageRoute<RecordDraft>(
        builder: (_) => RecordEditorPage(initial: record),
      ),
    );
    if (draft == null) return;
    widget.onEditRecord(record, draft);
    if (mounted) setState(() {});
  }

  Future<void> _deleteRecord(GiftRecord record) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return _ConfirmSheet(
          title: '删除该条记录？',
          message: '${record.occasion} · ${_formatSigned(record.signedAmount)}',
          dangerText: '确认删除',
          onConfirm: () => Navigator.of(sheetContext).pop(true),
        );
      },
    );
    if (shouldDelete == true) {
      widget.onDeleteRecord(record);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteContact() async {
    final deleted = await widget.onDeleteContact();
    if (deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.recordsForContact();
    final appBarTopInset =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    var received = 0;
    var returned = 0;
    for (final record in records) {
      if (record.type == GiftRecordType.received) {
        received += record.amount;
      } else {
        returned += record.amount;
      }
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('关系', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        actionsPadding: const EdgeInsets.only(right: 16),
        actions: [
          IconButton(
            onPressed: _deleteContact,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFA616A),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, appBarTopInset, 16, 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFFFE5E8),
                      child: Text(
                        widget.contact.name.characters.first,
                        style: const TextStyle(
                          color: Color(0xFFEA606B),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.contact.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            widget.groupLabel,
                            style: const TextStyle(
                              color: Color(0xFF8B8B8B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(label: '累计支出', value: '-$returned'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(label: '累计收入', value: '+$received'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: '差额',
                      value: _formatSigned(widget.netAmount()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    '来往记录',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _addRecord,
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFFFA636B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: records.isEmpty
                    ? _EmptyRecordsPanel(onAdd: _addRecord)
                    : MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: ListView.builder(
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  onTap: () => _editRecord(record),
                                  title: Text(
                                    record.occasion,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(_formatDate(record.date)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatSigned(record.signedAmount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: record.signedAmount >= 0
                                              ? const Color(0xFF222222)
                                              : const Color(0xFFFA5F68),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteRecord(record),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFFA616A),
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordEditorPage extends StatefulWidget {
  const RecordEditorPage({super.key, this.initial});

  final GiftRecord? initial;

  @override
  State<RecordEditorPage> createState() => _RecordEditorPageState();
}

class _RecordEditorPageState extends State<RecordEditorPage> {
  late GiftRecordType _type;
  late DateTime _date;
  late TextEditingController _amountController;
  late TextEditingController _occasionController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _type = widget.initial?.type ?? GiftRecordType.received;
    _date = widget.initial?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: widget.initial?.amount.toString() ?? '200',
    );
    _occasionController = TextEditingController(
      text: widget.initial?.occasion ?? '礼金',
    );
    _noteController = TextEditingController(text: widget.initial?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _occasionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    const themeRed = Color(0xFFF12530);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: themeRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              surfaceContainerHighest: Colors.white,
              surfaceContainerHigh: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return themeRed;
                return null;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return themeRed;
              }),
              todayBorder: const BorderSide(color: themeRed),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return themeRed;
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return null;
              }),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: themeRed,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  void _save() {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final occasion = _occasionController.text.trim();
    final note = _noteController.text.trim();
    if (amount <= 0 || occasion.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写有效金额和场景')));
      return;
    }
    Navigator.of(context).pop(
      RecordDraft(
        type: _type,
        amount: amount,
        date: _date,
        occasion: occasion,
        note: note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.initial == null ? '新增记录' : '编辑记录'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TypeToggle(
                      title: '收礼',
                      active: _type == GiftRecordType.received,
                      onTap: () =>
                          setState(() => _type = GiftRecordType.received),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TypeToggle(
                      title: '回礼',
                      active: _type == GiftRecordType.returned,
                      onTap: () =>
                          setState(() => _type = GiftRecordType.returned),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _LabeledInput(
                label: '金额',
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: '¥ '),
                ),
              ),
              const SizedBox(height: 10),
              _LabeledInput(
                label: '日期',
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE7E7EA)),
                    ),
                    child: Text(
                      _formatDate(_date),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LabeledInput(
                label: '场景',
                child: TextField(
                  controller: _occasionController,
                  decoration: const InputDecoration(hintText: '例如：生日、搬家、婚礼'),
                ),
              ),
              const SizedBox(height: 10),
              _LabeledInput(
                label: '备注',
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(hintText: '选填'),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFA636B),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFDFE3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFFA636B) : const Color(0xFFE8E8EC),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? const Color(0xFFFA636B) : const Color(0xFF6D6D6D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF353535),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8C8C8C),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF222222),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecordsPanel extends StatelessWidget {
  const _EmptyRecordsPanel({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 76,
            color: Color(0xFFE3E3E8),
          ),
          const SizedBox(height: 8),
          const Text(
            '还没有来往记录',
            style: TextStyle(
              color: Color(0xFF9A9AA1),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFA636B),
            ),
            child: const Text('添加记录'),
          ),
        ],
      ),
    );
  }
}

class _ContactEditorSheet extends StatefulWidget {
  const _ContactEditorSheet();

  @override
  State<_ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<_ContactEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  RelationGroup _selectedGroup = RelationGroup.friend;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写姓名')));
      return;
    }
    Navigator.of(context).pop(
      ContactDraft(
        name: name,
        group: _selectedGroup,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = math.max(0.0, MediaQuery.viewInsetsOf(context).bottom);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    '添加关系',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledInput(
                  label: '姓名',
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: '输入联系人名称'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '标签',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF353535),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final group in RelationGroup.values)
                      ChoiceChip(
                        label: Text(group.label),
                        selected: _selectedGroup == group,
                        onSelected: (_) =>
                            setState(() => _selectedGroup = group),
                        selectedColor: const Color(0xFFFFDDE1),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _LabeledInput(
                  label: '备注',
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(hintText: '选填'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFA636B),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteContactSheet extends StatelessWidget {
  const _DeleteContactSheet({
    required this.contactName,
    required this.onConfirm,
  });

  final String contactName;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '即将删除 $contactName 的关系',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'relation/1.png',
                  width: 156,
                  height: 156,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFE8E8EC),
                          foregroundColor: const Color(0xFF212121),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFFA636B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '确认删除',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.dangerText,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String dangerText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8B8B93),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFE8E8EC),
                          foregroundColor: const Color(0xFF212121),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFFA636B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          dangerText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDeleteRecordSheet extends StatelessWidget {
  const _HomeDeleteRecordSheet({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SizedBox(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: 3000 / 2904,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'home design1/7.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned(
                      left: w * 0.07,
                      right: w * 0.07,
                      bottom: h * 0.06,
                      height: h * 0.23,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).pop(false),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          SizedBox(width: w * 0.04),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onConfirm,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatSigned(int value) {
  if (value > 0) return '+$value';
  if (value < 0) return '$value';
  return '0';
}

String _formatStatsAxisValue(int value) {
  if (value >= 10000) {
    final compact = value / 10000;
    return '${compact.toStringAsFixed(compact.truncateToDouble() == compact ? 0 : 1)}w';
  }
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact.truncateToDouble() == compact ? 0 : 1)}k';
  }
  return value.toString();
}

// ignore: unused_element
final List<ContactProfile> _seedContacts = [
  const ContactProfile(
    id: 1,
    name: '佳慧',
    group: RelationGroup.friend,
    note: '大学同学',
  ),
  const ContactProfile(
    id: 2,
    name: '华强',
    group: RelationGroup.classmate,
    note: '老同学',
  ),
  const ContactProfile(
    id: 3,
    name: 'Mleo',
    group: RelationGroup.colleague,
    note: '团队伙伴',
  ),
  const ContactProfile(
    id: 4,
    name: '李克友',
    group: RelationGroup.relative,
    note: '家族长辈',
  ),
  const ContactProfile(
    id: 5,
    name: '李亮',
    group: RelationGroup.friend,
    note: '多年的朋友',
  ),
  const ContactProfile(
    id: 6,
    name: '阿伟',
    group: RelationGroup.colleague,
    note: '项目合作',
  ),
  const ContactProfile(
    id: 7,
    name: '小宇',
    group: RelationGroup.classmate,
    note: '高中同学',
  ),
];

// ignore: unused_element
final List<CalendarEntry> _seedCalendarEntries = [
  CalendarEntry(
    id: 1,
    dateTime: DateTime(2025, 5, 1, 10, 30),
    person: '佳慧',
    title: '生日安排',
    note: '提前准备蛋糕和祝福语',
  ),
  CalendarEntry(
    id: 2,
    dateTime: DateTime(2025, 5, 13, 18, 0),
    person: '阿伟',
    title: '同事婚礼',
    note: '晚上 6 点到酒店签到',
  ),
];

// ignore: unused_element
final List<GiftRecord> _seedRecords = [
  GiftRecord(
    id: 1,
    contactId: 1,
    type: GiftRecordType.received,
    amount: 1000,
    date: DateTime(2025, 5, 25),
    occasion: '生日',
    note: '小美女女儿满月',
  ),
  GiftRecord(
    id: 2,
    contactId: 2,
    type: GiftRecordType.received,
    amount: 500,
    date: DateTime(2025, 4, 20),
    occasion: '搬家',
    note: '新房乔迁',
  ),
  GiftRecord(
    id: 3,
    contactId: 3,
    type: GiftRecordType.received,
    amount: 300,
    date: DateTime(2025, 3, 10),
    occasion: '婚礼',
    note: '周末参加婚礼',
  ),
  GiftRecord(
    id: 4,
    contactId: 4,
    type: GiftRecordType.received,
    amount: 700,
    date: DateTime(2025, 1, 8),
    occasion: '升学宴',
    note: '孩子升学庆祝',
  ),
  GiftRecord(
    id: 101,
    contactId: 5,
    type: GiftRecordType.returned,
    amount: 1000,
    date: DateTime(2025, 6, 1),
    occasion: '生日',
    note: '礼尚往来',
  ),
  GiftRecord(
    id: 102,
    contactId: 6,
    type: GiftRecordType.returned,
    amount: 300,
    date: DateTime(2025, 5, 13),
    occasion: '结婚',
    note: '同事婚礼',
  ),
  GiftRecord(
    id: 103,
    contactId: 7,
    type: GiftRecordType.returned,
    amount: 520,
    date: DateTime(2025, 3, 9),
    occasion: '新居',
    note: '乔迁回礼',
  ),
];
