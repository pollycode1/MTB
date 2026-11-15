import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'attachments.dart';
import 'categories.dart';
import 'home_screen.dart';
import 'schedule_data.dart';
import 'tags.dart';
import 'notification_service.dart';
import 'laundry.dart';

/// Appends an error to Download/MTB/mtb-crash.txt (the native side writes there too),
/// so a crash on a phone without adb can still be read and sent back.
void logCrash(String where, Object error, StackTrace? stack) {
  final line = '--- ${DateTime.now()} dart $where\n$error\n$stack\n';
  // app files dir is always writable; the native side shows it after a crash
  for (final path in ['/data/user/0/com.example.mtb/files', '/storage/emulated/0/Download/MTB']) {
    try {
      final dir = Directory(path)..createSync(recursive: true);
      File('${dir.path}/mtb-crash.txt').writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}

/// One failing startup step must not keep the app from opening.
Future<void> _step(String name, Future<void> Function() run) async {
  try {
    await run();
  } catch (e, st) {
    logCrash('startup $name', e, st);
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      logCrash('flutter', d.exception, d.stack);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      logCrash('platform', e, st);
      return true;
    };
    await _step('notifications', NotificationService.init);
    await _step('categories', Categories.load);
    await _step('tags', Tags.load);
    await _step('attachments', Attachments.init);
    await _step('schedule', ScheduleStore.load);
    await _step('holidays', Holidays.load);
    await _step('laundry', Laundry.load);
    runApp(const MTBApp());
  }, (e, st) => logCrash('zone', e, st));
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
