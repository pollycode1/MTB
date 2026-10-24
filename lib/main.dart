import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'attachments.dart';
import 'categories.dart';
import 'home_screen.dart';
import 'schedule_data.dart';
import 'tags.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Categories.load();
  await Tags.load();
  await Attachments.init();
  await ScheduleStore.load();
  await Holidays.load();
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
