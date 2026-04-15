import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/data_providers.dart';
import 'providers/audio_providers.dart';
import 'ui/theme.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('availabilityCache');
  await Hive.openBox('user_prefs');
  await Hive.openBox('downloaded_files');

  // Pre-initialize the audio service once at startup so the provider
  // never races or double-calls AudioService.init.
  try {
    await initAudioService();
  } catch (e, st) {
    debugPrint('[AudioService] Pre-init failed: $e');
    debugPrint('[AudioService] Stack trace:\n$st');
  }

  runApp(
    const ProviderScope(
      child: NoorAlQiraatApp(),
    ),
  );
}

class NoorAlQiraatApp extends ConsumerWidget {
  const NoorAlQiraatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noor Al-Qira\'at',
      theme: AppTheme.islamicTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
      ],
      locale: const Locale('ar', 'AE'),
      home: const InitializationScreen(),
    );
  }
}

class InitializationScreen extends ConsumerWidget {
  const InitializationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrlAsync = ref.watch(activeBaseUrlProvider);
    final quranAsync = ref.watch(quranIndexProvider);
    final mutoonAsync = ref.watch(mutoonIndexProvider);
    final audioAsync = ref.watch(audioHandlerProvider);

    return Scaffold(
      body: baseUrlAsync.when(
        data: (_) => quranAsync.when(
          data: (_) => mutoonAsync.when(
            data: (_) => audioAsync.when(
              data: (_) => const HomeScreen(),
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
              error: (e, st) => Center(child: Text('Error initializing audio: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading Mutoon Index: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error loading Quran Index: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error fetching remote config: $e')),
      ),
    );
  }
}
