class Endpoints {
  Endpoints._();

  static const String sendOtp = '/users/send-otp/';
  static const String verifyOtp = '/users/verify-otp/';
  static const String me = '/users/me/';
  static const String meAvatar = '/users/me/avatar/';
  static const String aiMentorAsk = '/users/ai/mentor/ask/';

  static const String categories = '/courses/categories/';
  static const String courses = '/courses/';
  static const String promotions = '/courses/promotions/';
  static String courseDetail(int id) => '/courses/$id/';
  static String courseReview(int id) => '/courses/$id/review/';

  static String lessonDetail(int id) => '/lessons/$id/';

  static String quizByLesson(int lessonId) => '/quizzes/lesson/$lessonId/';
  static String quizSubmit(int quizId) => '/quizzes/$quizId/submit/';

  static const String continueLearning = '/courses/continue/';
  static const String homeFeed = '/courses/home-feed/';

  static const String profile = '/gamification/profile/';
  static const String leaderboard = '/gamification/leaderboard/';
  static String leaderboardUser(int userId) => '/gamification/leaderboard/$userId/';
  static const String analytics = '/gamification/analytics/';
  static const String paymentAnalytics = '/gamification/payments/';

  // Admin CRUD
  static const String adminCategories = '/courses/admin/categories/';
  static String adminCategory(int id) => '/courses/admin/categories/$id/';
  static const String adminCourses = '/courses/admin/courses/';
  static String adminCourse(int id) => '/courses/admin/courses/$id/';
  static const String adminModules = '/courses/admin/modules/';
  static String adminModule(int id) => '/courses/admin/modules/$id/';
  static const String adminDiscounts = '/courses/admin/discounts/';
  static String adminDiscount(int id) => '/courses/admin/discounts/$id/';
  static const String adminLessons = '/lessons/admin/lessons/';
  static String adminLesson(int id) => '/lessons/admin/lessons/$id/';

  // Admin Quiz CRUD
  static const String adminQuizzes = '/quizzes/admin/quizzes/';
  static String adminQuiz(int id) => '/quizzes/admin/quizzes/$id/';
  static const String adminQuestions = '/quizzes/admin/questions/';
  static String adminQuestion(int id) => '/quizzes/admin/questions/$id/';
  static const String adminAnswers = '/quizzes/admin/answers/';
  static String adminAnswer(int id) => '/quizzes/admin/answers/$id/';

  // Resume
  static const String resumeChoices = '/users/resume/choices/';
  static const String resumes = '/users/resume/';
  static String resumeDetail(int id) => '/users/resume/$id/';
  static String resumeDownload(int id) => '/users/resume/$id/download/';

  // Wallet
  static const String wallet = '/users/wallet/';
  static const String walletTransactions = '/users/wallet/transactions/';
  static const String adminTopup = '/users/admin/topup/';
  static String adminTransactionCheck(int id) => '/users/admin/transactions/$id/check/';
  static const String notifications = '/users/notifications/';
  static String notificationDetail(int id) => '/users/notifications/$id/';
  static const String notificationsReadAll = '/users/notifications/read-all/';
  static String notificationRead(int id) => '/users/notifications/$id/read/';
  static const String deviceToken = '/users/device-token/';

  // Course subscription
  static String subscription(int courseId) => '/courses/$courseId/subscription/';
  static String purchase(int courseId) => '/courses/$courseId/purchase/';
  static String renew(int courseId) => '/courses/$courseId/renew/';

  static const String markVideo = '/progress/mark-video/';
  static String courseProgress(int courseId) => '/progress/course/$courseId/';
  static String lessonStatus(int lessonId) => '/progress/lesson/$lessonId/';
  static const String progress = '/progress/';
}
