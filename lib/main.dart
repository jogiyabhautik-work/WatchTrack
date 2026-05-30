import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';
import 'package:watch_track/core/theme/theme_provider.dart';
import 'package:watch_track/core/providers/user_data_provider.dart';
import 'package:watch_track/core/providers/recommendation_provider.dart';
import 'package:watch_track/core/providers/auth_provider.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/core/providers/sync_provider.dart';
import 'package:watch_track/core/providers/watchlist_folder_provider.dart';
import 'package:watch_track/core/theme/app_theme.dart';
import 'package:watch_track/presentation/screens/splash/premium_splash_screen.dart';
import 'package:watch_track/presentation/screens/auth/login_screen.dart';
import 'package:watch_track/presentation/screens/main_screen.dart';
import 'package:watch_track/features/import_watchlist/presentation/watchlist_import_provider.dart';
import 'package:watch_track/features/import_watchlist/domain/import_matcher.dart';
import 'package:watch_track/features/import_watchlist/data/tmdb_import_repository.dart';
import 'package:watch_track/back-end/api_service.dart';
import 'package:watch_track/presentation/screens/main_screen.dart';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:watch_track/core/appwrite_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Automate Appwrite schema verification on startup
  try {
    await AppwriteSchemaManager.setupIfAvailable();
  } catch (e, stackTrace) {
    debugPrint('⚠️ Appwrite schema setup failed or skipped: $e');
    debugPrint(stackTrace.toString());
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProxyProvider<AuthProvider, SyncProvider>(
            create: (_) => SyncProvider(),
            update: (_, auth, syncProvider) => syncProvider!..setUserId(auth.user?.$id),
          ),
          ChangeNotifierProxyProvider<AuthProvider, UserDataProvider>(
            create: (_) => UserDataProvider(),
            update: (_, auth, user) => user!..setUserId(auth.user?.$id),
          ),
          ChangeNotifierProxyProvider2<AuthProvider, SyncProvider, TrackingProvider>(
            create: (_) => TrackingProvider(),
            update: (_, auth, sync, track) => track!
              ..setUserId(auth.user?.$id)
              ..setSyncProvider(sync),
          ),
          ChangeNotifierProxyProvider2<AuthProvider, SyncProvider, WatchlistFolderProvider>(
            create: (_) => WatchlistFolderProvider(),
            update: (_, auth, sync, folder) => folder!
              ..setUserId(auth.user?.$id)
              ..setSyncProvider(sync),
          ),
          ChangeNotifierProxyProvider2<TrackingProvider, WatchlistFolderProvider, WatchlistImportProvider>(
            create: (context) {
              final repo = TmdbImportRepository(ApiService());
              final matcher = ImportMatcher(repo);
              return WatchlistImportProvider(
                matcher,
                Provider.of<TrackingProvider>(context, listen: false),
                Provider.of<WatchlistFolderProvider>(context, listen: false),
              );
            },
            update: (_, tracking, folder, provider) {
              // Ensure we maintain reference to latest providers if they change
              return provider ?? WatchlistImportProvider(
                ImportMatcher(TmdbImportRepository(ApiService())), 
                tracking, 
                folder
              );
            },
          ),
          ChangeNotifierProvider(create: (_) => RecommendationProvider()),
        ],
        child: const CineTrackApp(),
      ),
    ),
  );
}

class CineTrackApp extends StatelessWidget {
  const CineTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          useInheritedMediaQuery: true,
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          title: 'CINE Track',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.status == AuthStatus.authenticated) {
                return const MainScreen();
              }
              // Only show splash screen on initial check
              if (auth.status == AuthStatus.initial) {
                return const PremiumSplashScreen();
              }
              // Default to LoginScreen for unauthenticated and authenticating states
              // so the user can see loading indicators on the login/register buttons
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
