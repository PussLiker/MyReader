import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/presentation/screens/library_screen.dart';
import 'package:my_reader/presentation/providers/theme_provider.dart';
import 'app_colors.dart';

void main() {
  runApp(const ProviderScope(child: MyReaderApp()));
}

class MyReaderApp extends ConsumerWidget {
  const MyReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    ThemeData createTheme(AppColors colors, Brightness brightness) {
      return ThemeData(
        brightness: brightness,
        extensions: <ThemeExtension<dynamic>>[colors],
        scaffoldBackgroundColor: colors.background,
        primaryColor: colors.accent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ),
        fontFamily: 'serif',
        appBarTheme: AppBarTheme(
            backgroundColor: colors.accent, foregroundColor: colors.mainText),
        useMaterial3: true,
      );
    }

    return MaterialApp(
      title: 'My Reader',
      debugShowCheckedModeBanner: false,
      theme: createTheme(AppColors.light, Brightness.light),
      darkTheme: createTheme(AppColors.dark, Brightness.dark),
      themeMode: themeMode,
      home: const LibraryScreen(),
    );
  }
}
