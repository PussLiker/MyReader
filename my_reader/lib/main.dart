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
      theme: ThemeData(
        primaryColor: const Color(0xFFD7CCC8),
        scaffoldBackgroundColor: const Color(0xFFF5F5DC),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF5D4037)),
          titleLarge: TextStyle(color: Color(0xFF5D4037)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF8D6E63)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D6E63),
            foregroundColor: const Color(0xFFF5F5DC),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}