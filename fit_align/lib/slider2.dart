import 'package:fit_align/signIN.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

class sliderview extends StatefulWidget {
  const sliderview({super.key});

  @override
  State<sliderview> createState() => _sliderviewState();
}

class _sliderviewState extends State<sliderview> {
  static const List<({String title, String body, String image})> _slides = [
    (
      title: "AI Posture Tracking",
      body: "Track your fitness posture in real-time using your device camera. Our smart AI ensures you perform every exercise with perfect form to prevent injuries.",
      image: "https://static.vecteezy.com/system/resources/thumbnails/025/214/034/small/3d-sportsman-character-performing-dumbbell-split-squats-right-png.png",
    ),
    (
      title: "Real-Time Audio Guide",
      body: "Get instant voice alerts and live feedback whenever your posture goes wrong. It's like having a personal gym trainer inside your pocket 24/7.",
      image: "https://static.vecteezy.com/system/resources/previews/025/213/947/non_2x/3d-sporty-male-character-performing-standard-push-up-exercise-at-home-gym-png.png",
    ),
    (
      title: "Analyze Your Progress",
      body: "Monitor your daily workout stats, track accuracy scores for different exercises, and watch yourself improve day by day with detailed analytics.",
      image: "https://static.vecteezy.com/system/resources/previews/025/213/959/non_2x/3d-sporty-male-character-nailing-the-side-plank-exercise-at-home-gym-png.png",
    ),
  ];

  void _goToSignIn() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const signin()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final decoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.onSurface),
      bodyTextStyle: TextStyle(fontSize: 15, color: cs.onSurfaceVariant, height: 1.5),
      imagePadding: const EdgeInsets.only(top: 40),
      pageColor: cs.surface,
      contentMargin: const EdgeInsets.symmetric(horizontal: 24),
    );

    return Scaffold(
      body: SafeArea(
        child: IntroductionScreen(
          globalBackgroundColor: cs.surface,
          pages: _slides
              .map((slide) => PageViewModel(
                    title: slide.title,
                    body: slide.body,
                    decoration: decoration,
                    image: Container(
                      height: 280,
                      width: 280,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Image.network(
                        slide.image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: cs.primary, size: 80),
                      ),
                    ),
                  ))
              .toList(),
          onDone: _goToSignIn,
          onSkip: _goToSignIn,
          showSkipButton: true,
          skip: Text("Skip", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w600)),
          next: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
            child: Icon(Icons.arrow_forward_rounded, color: cs.onPrimary, size: 22),
          ),
          done: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: cs.primary),
            child: Text("Done", style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          dotsDecorator: DotsDecorator(
            size: const Size(8, 8),
            activeSize: const Size(24, 8),
            activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            color: cs.outlineVariant,
            activeColor: cs.primary,
          ),
          animationDuration: 300,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}