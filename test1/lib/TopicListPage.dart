import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'CreateTopicPage.dart'; // Changed to CreateTopicPage
import 'TopicDetailsPage.dart';
import 'auth_service.dart';

class TopicsListPage extends StatefulWidget {
  const TopicsListPage({super.key});

  @override
  _TopicsListPageState createState() => _TopicsListPageState();
}

class _TopicsListPageState extends State<TopicsListPage> {
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchTopics();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _authService.isUserLoggedIn();
    if (mounted) setState(() => _isLoggedIn = loggedIn);
  }

  Future<void> _fetchTopics() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/topics'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
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
                if (_isLoggedIn) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CreateTopicPage()),
                        );
                        if (result == true) {
                          _fetchTopics(); // Refresh topics after new topic creation
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create New Topic',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Please log in to create a new topic.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchTopics,
                    child: _topics.isEmpty
                        ? const Center(
                            child: Text(
                              'No topics available',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _topics.length,
                            itemBuilder: (context, index) {
                              final topic = _topics[index];
                              final title = topic['topic'] ?? 'No Title';
                              String formattedDate = 'N/A';
                              if (topic['lastUpdatedAt'] != null) {
                                try {
                                  final parsedDate = DateTime.parse(topic['lastUpdatedAt']);
                                  formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
                                } catch (e) {
                                  print('Date parsing error: ${topic['lastUpdatedAt']} - $e');
                                }
                              } else if (topic['createdAt'] != null) {
                                try {
                                  final parsedDate = DateTime.parse(topic['createdAt']);
                                  formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
                                } catch (e) {
                                  print('Date parsing error: ${topic['createdAt']} - $e');
                                }
                              }
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    'Last updated: $formattedDate${topic['username'] != null ? ' by ${topic['username']}' : ''} | Category: ${topic['category'] ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TopicDetailsPage(topic: topic),
                                      ),
                                    );
                                    if (result == true) {
                                      _fetchTopics(); // Refresh topics after subtopic creation
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                    ),
                  ),
                ],
            ),
    );
  }
}
