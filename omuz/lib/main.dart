import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/courses/providers/course_provider.dart';
import 'features/home/providers/home_provider.dart';
import 'features/lessons/providers/lesson_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/quizzes/providers/quiz_provider.dart';
import 'features/resume/providers/resume_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        title: 'OMuz',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
