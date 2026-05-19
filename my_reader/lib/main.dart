import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/presentation/screens/library_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyReaderApp()));
}

class MyReaderApp extends StatelessWidget {
  const MyReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFBCAAA4),
        scaffoldBackgroundColor: const Color(0xFFF8F4F0),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFBCAAA4),
          secondary: Color(0xFF8D6E63),
          surface: Color(0xFFF8F4F0),
          onPrimary: Color(0xFF4E342E),
          onSecondary: Colors.white,
          onSurface: Color(0xFF4E342E),
        ),
        fontFamily: 'serif',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFBCAAA4),
          foregroundColor: Color(0xFF4E342E),
          centerTitle: false,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF4E342E)),
          bodyMedium: TextStyle(color: Color(0xFF4E342E)),
          titleLarge: TextStyle(color: Color(0xFF4E342E), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF7B5E57)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D6E63),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFFF5F1EB),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}