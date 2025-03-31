import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'TopicDetailsPage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Car Forum',
      home: const ForumPage(),
    );
  }
}

class ForumPage extends StatefulWidget {
  const ForumPage({Key? key}) : super(key: key);

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchTopics();
  }

Future<void> fetchTopics() async {
  try {
    final response = await http.get(Uri.parse('https://localhost:7164/api/forum/topics'));
    if (response.statusCode == 200 && mounted) {
      setState(() {
        _topics = List<Map<String, dynamic>>.from(json.decode(response.body));
        _filteredTopics = List.from(_topics);
      });
    } else {
      print('Error fetching topics: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception during fetchTopics: $e');
  }
}

  void _filterTopics(String query) {
    setState(() {
      _searchQuery = query;
      if (_searchQuery.isNotEmpty) {
        _filteredTopics = _topics.where((topic) {
          final topicTitle = topic['topic']?.toLowerCase() ?? '';
          return topicTitle.contains(_searchQuery.toLowerCase());
        }).toList();
      } else {
        _filteredTopics = List.from(_topics);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forum')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            _buildFeaturedText(),
            const SizedBox(height: 10),
            Expanded(child: _buildTopicsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: _filterTopics,
      decoration: const InputDecoration(
        hintText: 'Search topics...',
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
        suffixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildFeaturedText() {
    return const Text(
      'Featured Topics',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

 Widget _buildTopicsList() {
  return ListView.builder(
    itemCount: _filteredTopics.length,
    itemBuilder: (context, index) {
      final topic = _filteredTopics[index];
      final title = topic['topic'] ?? 'N/A';
      final description = topic['description'] ?? 'No description';
      String formattedDate = 'N/A';

      final createdAt = topic['createdAt']; // Ensure this matches the field name in the response
      if (createdAt != null) {
        try {
          final parsedDate = DateTime.parse(createdAt.toString());
          formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
        } catch (e) {
          print('Date parsing error for topic "$title": $createdAt - $e');
          formattedDate = 'Invalid Date';
        }
      } else {
        print('No CreatedAt field for topic: $title');
      }

      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: const Icon(Icons.forum, color: Colors.blueAccent),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TopicDetailsPage(topic: topic),
              ),
            );
          },
        ),
      );
    },
  );
}
}