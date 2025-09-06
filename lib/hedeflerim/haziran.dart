import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yksgunluk/hedeflerim/konular.dart';

class HaziranWeeklyPlanPage extends StatefulWidget {
  const HaziranWeeklyPlanPage({Key? key}) : super(key: key);

  @override
  _HaziranWeeklyPlanPageState createState() => _HaziranWeeklyPlanPageState();
}

class _HaziranWeeklyPlanPageState extends State<HaziranWeeklyPlanPage> {
  List<List<String>> topicsToComplete = [[], [], [], []];
  List<List<String>> topicsToReview = [[], [], [], []];
  List<List<bool>> isCompleteChecked = [[], [], [], []];
  List<List<bool>> isReviewChecked = [[], [], [], []];
  bool isLoading = true;

  late String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; });

    List<List<String>> loadedComplete = [[], [], [], []];
    List<List<String>> loadedReview = [[], [], [], []];
    List<List<bool>> loadedCompleteChecked = [[], [], [], []];
    List<List<bool>> loadedReviewChecked = [[], [], [], []];

    for (int week = 0; week < 4; week++) {
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('haziranWeeklyPlan')
          .doc('week_$week')
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data()!;
        loadedComplete[week] = List<String>.from(data['completeTopics'] ?? []);
        loadedCompleteChecked[week] = List<bool>.from(data['completeChecked'] ?? List<bool>.filled(loadedComplete[week].length, false));
        loadedReview[week] = List<String>.from(data['reviewTopics'] ?? []);
        loadedReviewChecked[week] = List<bool>.from(data['reviewChecked'] ?? List<bool>.filled(loadedReview[week].length, false));
      } else {
        loadedCompleteChecked[week] = List<bool>.filled(loadedComplete[week].length, false);
        loadedReviewChecked[week] = List<bool>.filled(loadedReview[week].length, false);
      }
    }

    setState(() {
      topicsToComplete = loadedComplete;
      topicsToReview = loadedReview;
      isCompleteChecked = loadedCompleteChecked.map((l) => List<bool>.from(l, growable: true)).toList();
      isReviewChecked = loadedReviewChecked.map((l) => List<bool>.from(l, growable: true)).toList();
      isLoading = false;
    });
  }

  Future<void> _saveWeek(int week) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('haziranWeeklyPlan')
        .doc('week_$week')
        .set({
      'completeTopics': topicsToComplete[week],
      'completeChecked': isCompleteChecked[week],
      'reviewTopics': topicsToReview[week],
      'reviewChecked': isReviewChecked[week],
    }, SetOptions(merge: true));
  }

  void _addTopic(String topic, int weekIndex, String type) async {
    setState(() {
      if (type == "complete") {
        topicsToComplete[weekIndex].add(topic);
        while (isCompleteChecked.length <= weekIndex) {
          isCompleteChecked.add([]);
        }
        isCompleteChecked[weekIndex].add(false);
      } else if (type == "review") {
        topicsToReview[weekIndex].add(topic);
        while (isReviewChecked.length <= weekIndex) {
          isReviewChecked.add([]);
        }
        isReviewChecked[weekIndex].add(false);
      }
    });
    await _saveWeek(weekIndex);
  }

  void _removeTopic(String topic) async {
    setState(() {
      for (var weekIndex = 0; weekIndex < topicsToComplete.length; weekIndex++) {
        final topicIndex = topicsToComplete[weekIndex].indexOf(topic);
        if (topicIndex != -1) {
          topicsToComplete[weekIndex].removeAt(topicIndex);
          isCompleteChecked[weekIndex].removeAt(topicIndex);
        }
      }
      for (var weekIndex = 0; weekIndex < topicsToReview.length; weekIndex++) {
        final topicIndex = topicsToReview[weekIndex].indexOf(topic);
        if (topicIndex != -1) {
          topicsToReview[weekIndex].removeAt(topicIndex);
          isReviewChecked[weekIndex].removeAt(topicIndex);
        }
      }
    });
    for (var i = 0; i < 4; i++) {
      await _saveWeek(i);
    }
  }

  Widget _buildTopicItem(String topic, List<bool> statusList, int index, String type, int weekIndex) {
    return Row(
      children: [
        Expanded(
          child: Text(
            topic,
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.check_circle,
            color: statusList[index] ? Colors.green : Colors.grey,
          ),
          onPressed: () async {
            setState(() {
              statusList[index] = !statusList[index];
            });
            await _saveWeek(weekIndex);
          },
        ),
      ],
    );
  }

  Widget _buildTopicSection(String title, List<String> topics, List<bool> statusList, int weekIndex, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => YKSGunlugumPage(
                      ay: "Haziran",
                      onTopicAdded: (topic) {
                        _addTopic(topic, weekIndex, type);
                      },
                      onTopicRemoved: (topic) {
                        _removeTopic(topic);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        ...List.generate(topics.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: _buildTopicItem(topics[index], statusList, index, type, weekIndex),
          );
        }),
      ],
    );
  }

  Widget _buildWeekCard(int weekIndex) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black38,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${weekIndex + 1}. Hafta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            Divider(color: Colors.blueGrey.shade100, thickness: 1.2),
            SizedBox(height: 8),
            _buildTopicSection(
              'Bitireceğim Konular',
              topicsToComplete[weekIndex],
              isCompleteChecked[weekIndex],
              weekIndex,
              "complete",
            ),
            SizedBox(height: 14),
            _buildTopicSection(
              'Tekrar Edeceğim Konular',
              topicsToReview[weekIndex],
              isReviewChecked[weekIndex],
              weekIndex,
              "review",
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Haziran Haftalık Planlama'),
          backgroundColor: Colors.blue,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Haziran Haftalık Planlama'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 20),
        children: List.generate(4, (index) => _buildWeekCard(index)),
      ),
    );
  }
}