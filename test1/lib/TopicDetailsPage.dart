import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'SubTopicDetailsPage.dart'; // New page for discussion

class TopicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> topic;

  const TopicDetailsPage({Key? key, required this.topic}) : super(key: key);

  @override
  _TopicDetailsPageState createState() => _TopicDetailsPageState();
}

class _TopicDetailsPageState extends State<TopicDetailsPage> {
  List<Map<String, dynamic>> _subtopics = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final TextEditingController _subtopicController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchSubtopics();
  }

 Future<void> _checkLoginStatus() async {
  final loggedIn = await _authService.isUserLoggedIn();
  if (mounted) setState(() => _isLoggedIn = loggedIn);
}

Future<void> _fetchSubtopics() async {
  final topicId = widget.topic['id'];
  print('Fetching subtopics for Topic ID: $topicId');
  if (topicId == null) {
    if (mounted) setState(() => _isLoading = false);
    return;
  }

  try {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/forum/topics/$topicId/subtopics'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    print('Fetch Subtopics Response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200 && mounted) {
      setState(() {
        _subtopics = List<Map<String, dynamic>>.from(json.decode(response.body));
        _isLoading = false;
      });
    } else {
      showFailed(context, 'Failed to load subtopics: ${response.statusCode} - ${response.body}');
      if (mounted) setState(() => _isLoading = false);
    }
  } catch (e) {
    showFailed(context, 'Error fetching subtopics: $e');
    if (mounted) setState(() => _isLoading = false);
  }
}


  Future<void> _createSubtopic() async {
    if (_subtopicController.text.trim().isEmpty) {
      showWarning(context, 'Subtopic title cannot be empty');
      return;
    }

    final token = await _authService.getToken();
    final topicId = widget.topic['id'];

    if (token == null || topicId == null) {
      showFailed(context, 'Authentication error');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/forum/topics/$topicId/subtopics'), // Adjusted endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': _subtopicController.text.trim(),
          'description': '', // Add description field if needed
        }),
      );

      print('Create Subtopic Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201) {
        showSuccess(context, 'Subtopic created successfully');
        _subtopicController.clear();
        await _fetchSubtopics();
      } else {
        showFailed(context, 'Failed to create subtopic: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      showFailed(context, 'Error creating subtopic: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic['topic'] ?? 'Topic Details'),
        backgroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${widget.topic['category'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(widget.topic['description'] ?? 'No description', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Posted on: ${widget.topic['createdAt'] ?? 'N/A'} by ${widget.topic['username'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            const Text('Subtopics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_isLoggedIn) ...[
              TextField(
                controller: _subtopicController,
                decoration: InputDecoration(
                  labelText: 'Add a subtopic...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _createSubtopic),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 20),
            ],
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subtopics.isEmpty
                    ? const Text('No subtopics yet', style: TextStyle(color: Colors.grey))
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _subtopics.length,
                          itemBuilder: (context, index) {
                            final subtopic = _subtopics[index];
                            final title = subtopic['title'] ?? 'No title';
                            String formattedDate = 'N/A';
                            if (subtopic['createdAt'] != null) {
                              try {
                                final parsedDate = DateTime.parse(subtopic['createdAt']);
                                formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
                              } catch (e) {
                                print('Date parsing error: ${subtopic['createdAt']} - $e');
                              }
                            }
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(title),
                                subtitle: Text('Posted on: $formattedDate by ${subtopic['username'] ?? 'Unknown'}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SubtopicDetailsPage(subtopic: subtopic),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subtopicController.dispose();
    super.dispose();
  }
}