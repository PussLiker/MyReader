// my_reader/lib/main.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/presentation/screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().database;
  runApp(ProviderScope(child: MyReaderApp()));
}

class MyReaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyReader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LibraryScreen(),
        '/reader': (context) => Scaffold(
          body: Center(child: Text('ReaderScreen Placeholder')),
        ),
      },
    );
  }
}