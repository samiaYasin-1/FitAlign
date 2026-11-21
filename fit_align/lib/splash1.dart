import 'package:fit_align/signIN.dart';
import 'package:fit_align/slider2.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  bool isHome = false;
  bool _dataLoaded = false;
  bool _navigated = false;

  late final AnimationController _logoController;
  late final AnimationController _ringController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
    _logoFade = CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.5, curve: Curves.easeIn));
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _logoController.forward();
    loadingData();
  }

  Future<void> loadingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');
    final bool loggedIn = !(email == null || email.isEmpty || email == "null");

    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    setState(() {
      isHome = loggedIn;
      _dataLoaded = true;
    });
    _navigate();
  }

  void _navigate() {
    if (_navigated || !_dataLoaded || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => isHome ? const sliderview() : const signin(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const deepTeal = Color(0xFF1E8F85);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.2,
            colors: [cs.surfaceContainerHigh, cs.surface],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 170,
                width: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _ringController,
                      child: CustomPaint(size: const Size(170, 170), painter: _RingPainter(cs.primary)),
                    ),
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Container(
                          height: 120,
                          width: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [cs.primary, deepTeal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [BoxShadow(color: cs.primary.withAlpha(110), blurRadius: 30, spreadRadius: 2)],
                          ),
                          child: Text(
                            'F',
                            style: TextStyle(color: cs.onPrimary, fontSize: 64, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _logoFade,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [cs.primary, deepTeal]).createShader(bounds),
                  child: const Text(
                    'FIT_align',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Align your fitness journey',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color, Colors.transparent, Colors.transparent, color],
        stops: const [0.0, 0.25, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.color != color;
}