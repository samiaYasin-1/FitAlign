import 'package:flutter/material.dart';

class Exercise extends StatefulWidget {
  const Exercise({super.key});

  @override
  State<Exercise> createState() => _ExerciseState();
}

class _ExerciseState extends State<Exercise> {
  int _selectedFilter = 0;

  final List<String> filters = ['All', 'Strength', 'Cardio'];

  final List<({String name, String image, String duration, String score})> exercises = [
    (
      name: 'Squats',
      image: 'https://static.vecteezy.com/system/resources/thumbnails/025/214/034/small/3d-sportsman-character-performing-dumbbell-split-squats-right-png.png',
      duration: '30 Min',
      score: '85%',
    ),
    (
      name: 'Push Up',
      image: 'https://static.vecteezy.com/system/resources/previews/025/213/947/non_2x/3d-sporty-male-character-performing-standard-push-up-exercise-at-home-gym-png.png',
      duration: '20 Min',
      score: '75%',
    ),
    (
      name: 'Plank',
      image: 'https://static.vecteezy.com/system/resources/previews/025/213/959/non_2x/3d-sporty-male-character-nailing-the-side-plank-exercise-at-home-gym-png.png',
      duration: '15 Min',
      score: '65%',
    ),
    (
      name: 'Lunges',
      image: 'https://static.vecteezy.com/system/resources/previews/025/213/787/non_2x/3d-sporty-male-character-performing-dynamic-lunges-at-the-gym-png.png',
      duration: '25 Min',
      score: '55%',
    ),
    (
      name: 'Bicep Curl',
      image: 'https://static.vecteezy.com/system/resources/previews/025/213/897/non_2x/3d-sportsman-character-performing-dumbbell-reverse-curl-png.png',
      duration: '10 Min',
      score: '45%',
    ),
    (
      name: 'Shoulder Press',
      image: 'https://static.vecteezy.com/system/resources/previews/025/214/141/non_2x/3d-sportsman-character-sculpting-strong-shoulders-with-dumbbell-shoulder-bench-press-png.png',
      duration: '35 Min',
      score: '35%',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Select Exercise', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final selected = index == _selectedFilter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = index),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: selected ? cs.primary : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
                    ),
                    child: Text(
                      filters[index],
                      style: TextStyle(
                        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = exercises[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.image,
                          fit: BoxFit.cover,
                          width: 52,
                          height: 52,
                          errorBuilder: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: cs.outlineVariant,
                            child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.name, style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      Text(item.duration, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 14),
                      Text(item.score, style: TextStyle(color: cs.secondary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}