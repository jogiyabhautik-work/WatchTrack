import 'package:flutter/material.dart';
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

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:watch_track/core/providers/audio_player_provider.dart';
import 'package:watch_track/core/providers/lyrics_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:watch_track/core/services/audio_handler.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:watch_track/presentation/screens/auth/reset_password_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watch_track/features/update/data/repositories/update_repository.dart';
import 'package:watch_track/features/update/presentation/cubit/update_cubit.dart';
import 'package:watch_track/features/update/presentation/cubit/update_state.dart';
import 'package:watch_track/features/update/presentation/screens/update_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late AudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  audioHandler = await AudioService.init(
    builder: () => SoundtrackAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.watchtrack.app.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/launcher_icon',
    ),
  );

  await dotenv.load(fileName: ".env");

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => LyricsProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (_, auth, syncProvider) =>
              syncProvider!..setUserId(auth.user?.$id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, UserDataProvider>(
          create: (_) => UserDataProvider(),
          update: (_, auth, user) => user!..setUserId(auth.user?.$id),
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          SyncProvider,
          TrackingProvider
        >(
          create: (_) => TrackingProvider(),
          update: (_, auth, sync, track) => track!
            ..setUserId(auth.user?.$id)
            ..setSyncProvider(sync),
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          SyncProvider,
          WatchlistFolderProvider
        >(
          create: (_) => WatchlistFolderProvider(),
          update: (_, auth, sync, folder) => folder!
            ..setUserId(auth.user?.$id)
            ..setSyncProvider(sync),
        ),
        ChangeNotifierProxyProvider2<
          TrackingProvider,
          WatchlistFolderProvider,
          WatchlistImportProvider
        >(
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
            return provider ??
                WatchlistImportProvider(
                  ImportMatcher(TmdbImportRepository(ApiService())),
                  tracking,
                  folder,
                );
          },
        ),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
      ],
      child: RepositoryProvider(
        create: (context) => UpdateRepository(),
        child: BlocProvider(
          create: (context) => UpdateCubit(context.read<UpdateRepository>())..checkForUpdates(),
          child: const TrackTubeApp(),
        ),
      ),
    ),
  );
}

class TrackTubeApp extends StatefulWidget {
  const TrackTubeApp({super.key});

  @override
  State<TrackTubeApp> createState() => _TrackTubeAppState();
}

class _TrackTubeAppState extends State<TrackTubeApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial app link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Failed to handle app link: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'reset-password') {
      final userId = uri.queryParameters['userId'];
      final secret = uri.queryParameters['secret'];
      
      if (userId != null && secret != null) {
        // Adding a slight delay to ensure the navigator is fully mounted
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                userId: userId,
                secret: secret,
              ),
            ),
          );
        });
      }
    } else if (uri.host == 'verify-email') {
      final userId = uri.queryParameters['userId'];
      final secret = uri.queryParameters['secret'];
      
      if (userId != null && secret != null) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verifying email...')),
            );
            final success = await context.read<AuthProvider>().verifyEmail(
              userId: userId,
              secret: secret,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Email verified successfully!' : 'Failed to verify email.'),
                  backgroundColor: success ? Colors.green : Colors.redAccent,
                ),
              );
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Track & Tube',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: BlocBuilder<UpdateCubit, UpdateState>(
            builder: (context, updateState) {
              if (updateState is UpdateAvailable && updateState.isForced) {
                return const UpdateScreen();
              }
              if (updateState is UpdateDownloading && (context.read<UpdateCubit>().state as dynamic).isForced == true) {
                // If it's forced and downloading, keep showing update screen.
                // Wait, state doesn't have isForced in UpdateDownloading. We'll just show UpdateScreen if we want.
                // A better way is to check if _currentUpdate.forceUpdate is true, but since we can't easily,
                // we'll rely on the UpdateScreen being pushed, OR we can just show UpdateScreen for all downloading states temporarily.
                return const UpdateScreen();
              }
              
              return Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.status == AuthStatus.authenticatedOnline || 
                      auth.status == AuthStatus.authenticatedOffline) {
                    return const MainScreen();
                  }
                  if (auth.status == AuthStatus.initial) {
                    return const PremiumSplashScreen();
                  }
                  return const LoginScreen();
                },
              );
            },
          ),
        );
      },
    );
  }
}
