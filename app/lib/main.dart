import 'package:material_ui/material_ui.dart';
import 'theme/devdiary_fonts.dart';

import 'screens/dashboard_screen.dart';
import 'screens/diary_list_screen.dart';
import 'services/diary_api_service.dart';
import 'services/visitor_id.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DiaryApiService.defaultVisitorId = await VisitorStore().load();
  runApp(const DevDiaryApp());
}

class DevDiaryColors {
  static const Color background = Color(0xFFECEFF5);
  static const Color card = Color(0xFFF7F8FC);

  static const Color blue = Color(0xFF2445A8);
  static const Color lightBlue = Color(0xFFD6E0FA);

  static const Color purple = Color(0xFF6F35D8);
  static const Color darkPurple = Color(0xFF5321B5);
  static const Color lightPurple = Color(0xFFE4D9FB);

  static const Color pink = Color(0xFFFF2E83);
  static const Color lightPink = Color(0xFFFFD3E4);

  static const Color text = Color(0xFF14213D);
  static const Color secondaryText = Color(0xFF5C6378);
  static const Color border = Color(0xFF7E88A5);
}

class DevDiaryApp extends StatelessWidget {
  const DevDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DevDiaryColors.blue,
        primary: DevDiaryColors.blue,
        secondary: DevDiaryColors.purple,
        tertiary: DevDiaryColors.pink,
        surface: DevDiaryColors.card,
      ),
    );

    return MaterialApp(
      title: 'DevDiary',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: DevDiaryColors.background,

        textTheme: baseTheme.textTheme.apply(
          fontFamily: DevDiaryFonts.ui,
          bodyColor: DevDiaryColors.text,
          displayColor: DevDiaryColors.text,
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: DevDiaryColors.pink,
            foregroundColor: Colors.white,
          ),
        ),

        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: DevDiaryColors.pink,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: CircleBorder(),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => Colors.white,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return DevDiaryColors.purple;
              }

              return const Color(0xFFE3E3EB);
            },
          ),
        ),
      ),

      home: const DevDiaryHome(),
    );
  }
}

class DevDiaryHome extends StatefulWidget {
  const DevDiaryHome({super.key});

  @override
  State<DevDiaryHome> createState() => _DevDiaryHomeState();
}

class _DevDiaryHomeState extends State<DevDiaryHome> {
  int _selectedIndex = 0;

  void _openDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
      ),
    );
  }

  void _onBottomNavigationTap(int index) {
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    if (index == 1) {
      _openDashboard();
      return;
    }

    if (index == 2) {
      setState(() {
        _selectedIndex = 2;
      });
      return;
    }

    if (index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impostazioni: sezione disponibile in un futuro aggiornamento.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DevDiaryColors.background,

      body: SafeArea(
        child: Column(
          children: [
            const _DevDiaryHeader(),

            Expanded(
              child: _selectedIndex == 2
                  ? const DiaryListScreen(
                      key: ValueKey('favorites'),
                      initialOnlyFavorites: true,
                    )
                  : const DiaryListScreen(
                      key: ValueKey('home'),
                    ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: DevDiaryColors.border,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _selectedIndex == 0,
                  onTap: () => _onBottomNavigationTap(0),
                ),

                _BottomItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Dashboard',
                  selected: false,
                  onTap: () => _onBottomNavigationTap(1),
                ),

                _BottomItem(
                  icon: _selectedIndex == 2
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: 'Preferiti',
                  selected: _selectedIndex == 2,
                  onTap: () => _onBottomNavigationTap(2),
                ),

                _BottomItem(
                  icon: Icons.settings_outlined,
                  label: 'Impostazioni',
                  selected: false,
                  onTap: () => _onBottomNavigationTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevDiaryHeader extends StatelessWidget {
  const _DevDiaryHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WavePainter(),
            ),
          ),

          const Positioned(
            top: 24,
            left: 70,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: DevDiaryColors.blue,
              size: 18,
            ),
          ),

          const Positioned(
            top: 54,
            left: 145,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: DevDiaryColors.pink,
              size: 10,
            ),
          ),

          const Positioned(
            top: 32,
            right: 180,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: DevDiaryColors.blue,
              size: 17,
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.asset(
                'assets/images/devdiary_logo.png',
                height: 112,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Positioned(
            top: 22,
            right: 26,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  final state =
                      context.findAncestorStateOfType<
                          _DevDiaryHomeState
                      >();

                  state?._openDashboard();
                },
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: DevDiaryColors.purple,
                    size: 27,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bluePaint = Paint()
      ..color = DevDiaryColors.blue.withValues(
        alpha: 0.42,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final purplePaint = Paint()
      ..color = DevDiaryColors.purple.withValues(
        alpha: 0.10,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final leftWave = Path()
      ..moveTo(0, 64)
      ..cubicTo(
        size.width * 0.12,
        90,
        size.width * 0.22,
        18,
        size.width * 0.42,
        28,
      );

    canvas.drawPath(leftWave, purplePaint);
    canvas.drawPath(leftWave, bluePaint);

    final secondLeftWave = Path()
      ..moveTo(0, 76)
      ..cubicTo(
        size.width * 0.15,
        102,
        size.width * 0.24,
        42,
        size.width * 0.40,
        40,
      );

    canvas.drawPath(
      secondLeftWave,
      bluePaint,
    );

    final rightWave = Path()
      ..moveTo(
        size.width * 0.60,
        32,
      )
      ..cubicTo(
        size.width * 0.73,
        18,
        size.width * 0.82,
        105,
        size.width,
        66,
      );

    canvas.drawPath(
      rightWave,
      purplePaint,
    );
    canvas.drawPath(
      rightWave,
      bluePaint,
    );

    final secondRightWave = Path()
      ..moveTo(
        size.width * 0.64,
        44,
      )
      ..cubicTo(
        size.width * 0.77,
        32,
        size.width * 0.88,
        116,
        size.width,
        78,
      );

    canvas.drawPath(
      secondRightWave,
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? DevDiaryColors.purple
        : DevDiaryColors.secondaryText;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 26,
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(fontFamily: DevDiaryFonts.ui, 
                color: color,
                fontSize: 11,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            if (selected)
              Container(
                width: 7,
                height: 7,
                decoration:
                    const BoxDecoration(
                  color:
                      DevDiaryColors.purple,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}