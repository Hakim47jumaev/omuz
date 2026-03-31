import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/omuz_ambient_background.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/courses/providers/course_provider.dart';
import 'features/home/providers/home_provider.dart';
import 'features/lessons/providers/lesson_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/quizzes/providers/quiz_provider.dart';
import 'features/resume/providers/resume_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Status bar: fullscreen YouTube may enable immersive mode — reset on cold start.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await AppConstants.init();
  await PushService.initFirebase();
  runApp(const OMuzApp());
}

class OMuzApp extends StatelessWidget {
  const OMuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => LessonProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ResumeProvider()),
      ],
      child: MaterialApp.router(
        title: 'Omuz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) =>
            OmuzAmbientShell(child: child ?? const SizedBox.shrink()),
        routerConfig: appRouter,
      ),
    );
  }
}
