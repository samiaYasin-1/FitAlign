import 'dart:convert';
import 'package:fit_align/camerapermission.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Exercisedetail extends StatefulWidget {
  final String catname;
  final String catId;
  const Exercisedetail({super.key, required this.catname, required this.catId});

  @override
  State<Exercisedetail> createState() => _ExercisedetailState();
}

class _ExercisedetailState extends State<Exercisedetail> {
  List data = [];
  List categories = [];
  bool _isLoading = false;
  String _errorMessage = "";

  ColorScheme get cs => Theme.of(context).colorScheme;

  Future<void> getPro() async {
    if (widget.catId.isEmpty) {
      setState(() => _errorMessage = "Invalid category selected");
      return;
    }
    try {
      var res = await http.post(
        Uri.parse("https://logixadev.com/Samia/SHEIN/getCatProducts.php"),
        body: {"catId": widget.catId},
      );
      if (res.statusCode != 200) return;
      var result = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        if (result is List) data.addAll(result);
      });
    } catch (e) {
      debugPrint("getPro error: $e");
    }
  }

  Future<void> allCategories() async {
    try {
      var res = await http.post(Uri.parse("https://devtechnical.com/samia/exerciselist.php"));
      if (res.statusCode != 200) return;
      var result = jsonDecode(res.body);
      if (!mounted) return;
      setState(() => categories = result is List ? result : []);
    } catch (e) {
      debugPrint("allCategories error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    Future.wait([allCategories(), getPro()]).whenComplete(() {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _startExercise() {
    if (widget.catId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to start, category missing")),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => Camerapermission()));
  }

  Widget _checklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exerciseName = widget.catname.isNotEmpty ? widget.catname : "Exercise";

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(exerciseName, style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Get ready for", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 4),
              Text(exerciseName, style: TextStyle(color: cs.onSurface, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Image.network(
                  "https://static.vecteezy.com/system/resources/thumbnails/025/214/034/small/3d-sportsman-character-performing-dumbbell-split-squats-right-png.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: cs.primary, size: 80),
                ),
              ),
              const SizedBox(height: 28),
              Text("Before you start", style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    _checklistItem("Stand in front of the camera"),
                    _checklistItem("Keep your full body visible"),
                    _checklistItem("Use good lighting"),
                    _checklistItem("Keep a proper distance"),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _startExercise,
                  child: _isLoading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("I'm Ready", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: Text(_errorMessage, style: TextStyle(color: cs.secondary, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}