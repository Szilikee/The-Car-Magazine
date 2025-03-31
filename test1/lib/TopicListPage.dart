import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'CreateTopicPage.dart';
import 'TopicDetailsPage.dart';
import 'auth_service.dart';

class TopicsListPage extends StatefulWidget {
  @override
  _TopicsListPageState createState() => _TopicsListPageState();
}

class _TopicsListPageState extends State<TopicsListPage> {
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  Future<void> _fetchTopics() async {
    try {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/topics'),
      );
      print('Fetch Topics Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _topics = List<Map<String, dynamic>>.from(json.decode(response.body));
          _isLoading = false;
        });
      } else {
        showFailed(context, 'Failed to load topics: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      showFailed(context, 'Error fetching topics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Topics'),
        backgroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTopicPage())),
                  child: const Text('Create New Topic'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      final topic = _topics[index];
                      return ListTile(
                        title: Text(topic['topic'] ?? 'No Title'),
                        subtitle: Text('Posted on: ${topic['createdAt'] ?? 'N/A'}'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TopicDetailsPage(topic: topic)),
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