import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_categories_screen.dart';
import '../../features/admin/presentation/admin_course_detail_screen.dart';
import '../../features/admin/presentation/admin_courses_screen.dart';
import '../../features/admin/presentation/admin_lessons_screen.dart';
import '../../features/admin/presentation/admin_modules_screen.dart';
import '../../features/admin/presentation/admin_analytics_screen.dart';
import '../../features/admin/presentation/admin_discounts_screen.dart';
import '../../features/admin/presentation/admin_payments_screen.dart';
import '../../features/admin/presentation/admin_panel_screen.dart';
import '../../features/admin/presentation/admin_topup_screen.dart';
import '../../features/admin/presentation/admin_quiz_screen.dart';
import '../../features/profile/presentation/leaderboard_user_screen.dart';
import '../../features/profile/presentation/transactions_screen.dart';
import '../../features/profile/presentation/notifications_screen.dart';
import '../../features/profile/presentation/notification_detail_screen.dart';
import '../../features/resume/presentation/resume_screen.dart';
import '../../features/resume/presentation/resume_builder_screen.dart';
import '../../features/resume/presentation/resume_view_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/module_detail_screen.dart';
import '../../features/lessons/presentation/lesson_screen.dart';
import '../../features/quizzes/presentation/quiz_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/ai/presentation/ai_mentor_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const PhoneScreen()),
    GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
    GoRoute(path: '/home', builder: (context, state) => const MainShell()),
    GoRoute(
      path: '/ai-mentor',
      builder: (context, state) {
        int? lessonId;
        final e = state.extra;
        if (e is int) {
          lessonId = e;
        } else if (e is Map) {
          final v = e['lesson_id'];
          if (v is int) lessonId = v;
        }
        return AiMentorScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: '/course/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CourseDetailScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/course/:courseId/module/:moduleId',
      builder: (context, state) {
        final courseId = int.parse(state.pathParameters['courseId']!);
        final moduleId = int.parse(state.pathParameters['moduleId']!);
        return ModuleDetailScreen(courseId: courseId, moduleId: moduleId);
      },
    ),
    GoRoute(
      path: '/lesson/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return LessonScreen(lessonId: id);
      },
    ),
    GoRoute(
      path: '/quiz/:lessonId',
      builder: (context, state) {
        final lessonId = int.parse(state.pathParameters['lessonId']!);
        return QuizScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: '/leaderboard/user/:userId',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['userId']!);
        return LeaderboardUserScreen(userId: id);
      },
    ),
    GoRoute(path: '/wallet/transactions', builder: (context, state) => const TransactionsScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(
      path: '/notifications/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return NotificationDetailScreen(id: id);
      },
    ),
    GoRoute(path: '/resume', builder: (context, state) => const ResumeScreen()),
    GoRoute(path: '/resume/create', builder: (context, state) => const ResumeBuilderScreen()),
    GoRoute(
      path: '/resume/:id/view',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ResumeViewScreen(resumeId: id);
      },
    ),
    // Admin routes
    GoRoute(path: '/admin', builder: (context, state) => const AdminPanelScreen()),
    GoRoute(path: '/admin/analytics', builder: (context, state) => const AdminAnalyticsScreen()),
    GoRoute(path: '/admin/discounts', builder: (context, state) => const AdminDiscountsScreen()),
    GoRoute(path: '/admin/payments', builder: (context, state) => const AdminPaymentsScreen()),
    GoRoute(path: '/admin/topup', builder: (context, state) => const AdminTopupScreen()),
    GoRoute(path: '/admin/categories', builder: (context, state) => const AdminCategoriesScreen()),
    GoRoute(path: '/admin/courses', builder: (context, state) => const AdminCoursesScreen()),
    GoRoute(
      path: '/admin/course/:id/modules',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AdminModulesScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/admin/course/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AdminCourseDetailScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/admin/module/:id/lessons',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AdminLessonsScreen(moduleId: id);
      },
    ),
    GoRoute(
      path: '/admin/lesson/:id/quiz',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final title = state.extra as String? ?? 'Lesson';
        return AdminQuizScreen(lessonId: id, lessonTitle: title);
      },
    ),
  ],
);
