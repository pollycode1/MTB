import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> widgetCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.setAppGroupId('group.com.example.mtb');
  if (uri == null) return;
  if (uri.host == 'toggle') {
    final idx = int.tryParse(uri.pathSegments.firstOrNull ?? '');
    if (idx == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks_json');
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    if (idx >= list.length) return;
    // toggle
    list[idx]['done'] = !(list[idx]['done'] as bool? ?? false);
    list[idx]['doneAt'] = list[idx]['done']
        ? DateTime.now().toIso8601String()
        : null;
    await prefs.setString('tasks_json', jsonEncode(list));
    // recalculate counts
    final pending = list.where((t) => !(t['done'] as bool? ?? false)).length;
    final total = list.length;
    await HomeWidget.saveWidgetData('pending_tasks', pending);
    await HomeWidget.saveWidgetData('total_tasks', total);
    // rebuild ordered list: pending first then done
    final pendingIdx = List.generate(list.length, (i) => i)
        .where((i) => !(list[i]['done'] as bool? ?? false))
        .toList();
    final doneIdx = List.generate(list.length, (i) => i)
        .where((i) => list[i]['done'] as bool? ?? false)
        .toList();
    final ordered = [...pendingIdx, ...doneIdx].take(3).toList();
    for (int i = 0; i < 3; i++) {
      if (i < ordered.length) {
        await HomeWidget.saveWidgetData(
            'task${i}_title', list[ordered[i]]['title'] as String);
        await HomeWidget.saveWidgetData(
            'task${i}_done', list[ordered[i]]['done'] as bool? ?? false);
        await HomeWidget.saveWidgetData('task${i}_idx', ordered[i]);
      } else {
        await HomeWidget.saveWidgetData<String?>('task${i}_title', null);
      }
    }
    await HomeWidget.updateWidget(androidName: 'MtbTasksWidget');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(widgetCallback);
  await NotificationService.init();
  runApp(const MTBApp());
}

class MTBApp extends StatelessWidget {
  const MTBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        textTheme: GoogleFonts.sarabunTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF1C1C1C),
        ),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        }),
      ),
      home: const HomeScreen(),
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
