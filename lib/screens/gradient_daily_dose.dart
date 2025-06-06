import 'dart:math';
import 'package:flutter/material.dart';
import '../models/dose.dart';
import 'daily_doseai.dart';
import '../services/ai_services.dart'; // ✅ Import AIService

class GradientDailyDoseSection extends StatefulWidget {
  const GradientDailyDoseSection({super.key});

  @override
  State<GradientDailyDoseSection> createState() => _GradientDailyDoseSectionState();
}

class _GradientDailyDoseSectionState extends State<GradientDailyDoseSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late Future<List<Dose>> _dosesFuture;
  List<Dose>? _displayDoses;

  @override
  void initState() {
    super.initState();
    _debugPrintResponses();
    _dosesFuture = _fetchDosesFromFirebase();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }

  void _debugPrintResponses() async {
    print('🔍 GradientDailyDoseSection: Debug - Printing all survey responses...');
    await DailyDoseAI.fetchAndPrintAllSurveyResponses();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Dose>> _fetchDosesFromFirebase() async {
  try {
    print('🔍 GradientDailyDoseSection: Starting to fetch survey responses...');
    final responses = await DailyDoseAI.getSurveyResponses();
    print('📊 GradientDailyDoseSection: Retrieved ${responses.length} responses from Firebase');

    if (responses.isEmpty) {
      print('📭 GradientDailyDoseSection: No responses found');
      return [];
    }

    List<Dose> doses = [];

    for (int i = 0; i < responses.length; i++) {
      final response = responses[i];
      final question = response['question']?.toString() ?? 'No question available';
      final rawAnswer = response['answer'];
      String answer;

      if (rawAnswer is List) {
        answer = rawAnswer.map((item) => item?.toString() ?? '').join(', ');
      } else {
        answer = rawAnswer?.toString() ?? 'No answer provided';
      }

      final questionIndex = response['questionIndex'] ?? i;

      // ✅ Send to AI and get doses
      final aiDoses = await AIService.sendSurveyEntry(
        question: question,
        answer: answer,
        index: questionIndex,
      );

      if (aiDoses != null && aiDoses.isNotEmpty) {
        final aiDose = aiDoses.first;
        final fullTitle = aiDose['title'] ?? 'Dose Title';
        final fullAnswer = aiDose['answer'] ?? 'Dose Content';

        final shortTitle = fullTitle.split(' ').take(3).join(' ');
        final shortAnswer = fullAnswer.split(' ').take(25).join(' ');

        doses.add(Dose(
          title: shortTitle,
          subtitle: aiDose['subtitle'] ?? '',
          answer: shortAnswer,
        ));
      }
    }

    print('✅ GradientDailyDoseSection: Successfully created ${doses.length} AI dose objects');
    return doses;

  } catch (e) {
    print('❌ GradientDailyDoseSection: Error fetching AI doses: $e');
    throw Exception('Failed to fetch AI doses: $e');
  }
}


  void _selectFiveUnique(List<Dose> allDoses) {
    if (_displayDoses != null || allDoses.isEmpty) return;
    final rnd = Random();
    final temp = List<Dose>.from(allDoses);
    temp.shuffle(rnd);
    _displayDoses = temp.length <= 5 ? temp : temp.sublist(0, 5);
  }

  void _refreshDoses() {
    setState(() {
      _dosesFuture = _fetchDosesFromFirebase();
      _displayDoses = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final alignmentX = _animation.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(alignmentX, 0),
                end: Alignment(alignmentX - 2, 0),
                colors: const [
                  Color(0xFFB3E5FC),
                  Color(0xFF81D4FA),
                  Color(0xFF4FC3F7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: FutureBuilder<List<Dose>>(
              future: _dosesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'Loading survey responses...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load survey responses\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshDoses,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final allDoses = snapshot.data ?? [];
                _selectFiveUnique(allDoses);

                if (_displayDoses == null || _displayDoses!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.quiz_outlined, size: 48, color: Colors.white),
                        const SizedBox(height: 8),
                        const Text(
                          'No survey responses available',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Complete the survey to see responses here',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _refreshDoses,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                final doses = _displayDoses!;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Survey Highlights (${doses.length})',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: _refreshDoses,
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            tooltip: 'Refresh responses',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: doses.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final dose = doses[index];
                          return Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dose.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${index + 1}/${doses.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  dose.subtitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      dose.answer,
                                      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
