import 'package:flutter/material.dart';
import 'src/core/supabase/supabase_manager.dart';
import 'src/core/module/auth/presentation/pages/sign_in_page.dart';
import 'src/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseManager.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hotel Booking',
      theme: AppTheme.lightTheme,
      home: const SignInPage(),
    );
  }
}
