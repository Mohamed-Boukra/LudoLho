import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'providers/game_provider.dart';
import 'screens/start_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ScreenUtilInit(
            designSize: _getDesignSize(constraints.maxWidth),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, _) {
              return MaterialApp(
                title: 'Ludo',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  scaffoldBackgroundColor: AppColors.scaffoldBackground,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.red,
                    brightness: Brightness.dark,
                  ),
                  textTheme: GoogleFonts.baloo2TextTheme(
                    ThemeData(brightness: Brightness.dark).textTheme,
                  ),
                  splashFactory: InkSparkle.splashFactory,
                ),
                themeAnimationDuration: const Duration(milliseconds: 350),
                themeAnimationCurve: Curves.easeInOut,
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.noScaling),
                    child: child!,
                  );
                },
                home: const StartScreen(),
              );
            },
          );
        },
      ),
    );
  }
}


Size _getDesignSize(double width) {
  if (width < 600) return const Size(360, 690); // phones
  if (width < 1200) return const Size(834, 1194); // tablets
  return const Size(1440, 1024); // desktop / web
}
