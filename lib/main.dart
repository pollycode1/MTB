import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

void main() => runApp(const MTBApp());

class MTBApp extends StatelessWidget {
  const MTBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.sarabunTextTheme(), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
