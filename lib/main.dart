import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/gallery_cleaner/presentation/pages/gallery_swiper_page.dart';

void main() {
  // Ensure native bindings are initialized before accessing databases/channels
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: PicClawApp(),
    ),
  );
}

class PicClawApp extends StatelessWidget {
  const PicClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PicClaw',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const GallerySwiperPage(),
    );
  }
}
