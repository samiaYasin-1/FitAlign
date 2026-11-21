import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fit_align/camera.dart';
import 'package:fit_align/exercise.dart';
import 'package:fit_align/exercisedetail.dart';
import 'package:fit_align/splash1.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit Align',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF34D1BF),
          onPrimary: Color(0xFF04201C),
          secondary: Color(0xFFFF7A59),
          surface: Color(0xFF0C1317),
          surfaceContainerHigh: Color(0xFF142027),
          outlineVariant: Color(0xFF22323B),
          onSurface: Color(0xFFF2F7F9),
          onSurfaceVariant: Color(0xFF8DA2AD),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C1317),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C1317),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: Splash(),
    );
  }
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List productList = [];
  List categoryList = [];

  final List<String> durationLabels = ['30 Min', '20 Min', '15 Min', '25 Min', '10 Min', '35 Min'];
  final List<String> scoreLabels = ['85%', '75%', '65%', '55%', '45%', '35%'];

  final List<String> img = [
    'https://static.vecteezy.com/system/resources/previews/025/213/947/non_2x/3d-sporty-male-character-performing-standard-push-up-exercise-at-home-gym-png.png',
    'https://static.vecteezy.com/system/resources/previews/025/213/959/non_2x/3d-sporty-male-character-nailing-the-side-plank-exercise-at-home-gym-png.png',
    'https://static.vecteezy.com/system/resources/previews/025/213/787/non_2x/3d-sporty-male-character-performing-dynamic-lunges-at-the-gym-png.png',
    'https://static.vecteezy.com/system/resources/previews/025/213/897/non_2x/3d-sportsman-character-performing-dumbbell-reverse-curl-png.png',
    'https://static.vecteezy.com/system/resources/previews/025/214/034/small/3d-sportsman-character-performing-dumbbell-split-squats-right-png.png',
  ];

  ColorScheme get cs => Theme.of(context).colorScheme;

  Future<void> fetchAllProducts() async {
    try {
      final response = await http.post(Uri.parse("https://devtechnical.com/samia/all_products.php"));
      final decoded = jsonDecode(response.body);
      setState(() {
        if (decoded is List) {
          productList = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          productList = decoded['data'];
        } else {
          productList = [];
        }
      });
    } catch (e) {
      debugPrint("fetchAllProducts error: $e");
    }
  }

  Future<void> fetchAllCategories() async {
    try {
      final response = await http.post(Uri.parse("https://devtechnical.com/samia/exerciselist.php"));
      final decoded = jsonDecode(response.body);
      setState(() => categoryList = decoded is List ? decoded : []);
    } catch (e) {
      debugPrint("fetchAllCategories error: $e");
      setState(() => categoryList = []);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchAllCategories();
    fetchAllProducts();
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _thumb(String url, double w, double h, double radius, {BoxFit fit = BoxFit.cover}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        fit: fit,
        width: w,
        height: h,
        errorBuilder: (_, __, ___) => Container(
          width: w,
          height: h,
          color: cs.outlineVariant,
          child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _header(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text('View all', style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  BoxDecoration _card(double radius) => BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello Friend", style: TextStyle(fontSize: 20, color: cs.onSurface, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text("Ready to move? Let's improve.", style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: _card(14),
            child: Icon(Icons.notifications_none_rounded, color: cs.onSurface, size: 20),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary, width: 1.5)),
            child: ClipOval(
              child: Image.network(
                'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRyWDVogvyAyFNGIS3h9VI42VzkRO7KjgZk8g&s',
                fit: BoxFit.cover,
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => Icon(Icons.person, color: cs.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Featured Workouts'),
            const SizedBox(height: 14),
            Container(
              decoration: _card(22),
              clipBehavior: Clip.antiAlias,
              child: CarouselSlider(
                options: CarouselOptions(autoPlay: true, viewportFraction: 1, height: 200),
                items: img.map((url) => _thumb(url, double.infinity, 200, 0, fit: BoxFit.contain)).toList(),
              ),
            ),
            const SizedBox(height: 28),
            _header('Quick Start'),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _open(CameraScreen()),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [cs.primary, const Color(0xFF1E8F85)]),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.network(
                        'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRTlTDyK1pc-CrSK4au5oG3gfbgDOlSsaR_xw&s',
                        fit: BoxFit.cover,
                        width: 52,
                        height: 52,
                        errorBuilder: (_, __, ___) => Icon(Icons.person, color: cs.onPrimary, size: 40),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start Workout', style: TextStyle(color: cs.onPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                          Text("Let's begin your session", style: TextStyle(color: cs.onPrimary, fontSize: 12)),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.onPrimary,
                      child: Icon(Icons.arrow_forward_rounded, color: cs.primary, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _header('Popular Exercises', onViewAll: () => _open(Exercise())),
            const SizedBox(height: 14),
            SizedBox(
              height: 128,
              child: categoryList.isEmpty
                  ? Center(child: Text('Loading exercises...', style: TextStyle(color: cs.onSurfaceVariant)))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categoryList.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _open(Exercisedetail(
                          catname: categoryList[index]['name'] ?? '',
                          catId: categoryList[index]['Id'] ?? '',
                        )),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: _card(18),
                          child: Column(
                            children: [
                              _thumb(categoryList[index]['image'] ?? '', 84, 68, 12),
                              const SizedBox(height: 10),
                              Text(
                                categoryList[index]['name'] ?? 'Exercise',
                                style: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 28),
            _header('Recent Workouts'),
            const SizedBox(height: 14),
            if (categoryList.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No recent workouts', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryList.length > 10 ? 10 : categoryList.length,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: _card(16),
                  child: Row(
                    children: [
                      _thumb(categoryList[index]['image'] ?? '', 48, 48, 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          categoryList[index]['name'] ?? 'Exercise',
                          style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(durationLabels[index % durationLabels.length], style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 14),
                      Text(scoreLabels[index % scoreLabels.length], style: TextStyle(color: cs.secondary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}