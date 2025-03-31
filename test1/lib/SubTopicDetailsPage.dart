import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'TopicDetailsPage.dart';

class SubtopicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> subtopic;

  const SubtopicDetailsPage({Key? key, required this.subtopic}) : super(key: key);

  @override
  _SubtopicDetailsPageState createState() => _SubtopicDetailsPageState();
}

class _SubtopicDetailsPageState extends State<SubtopicDetailsPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final TextEditingController _postController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchPosts();
  }

Future<void> _checkLoginStatus() async {
  final loggedIn = await _authService.isUserLoggedIn();
  if (mounted) setState(() => _isLoggedIn = loggedIn);
}

Future<void> _fetchPosts() async {
  final subtopicId = widget.subtopic['id'];
  print('Fetching posts for Subtopic ID: $subtopicId');
  if (subtopicId == null) {
    if (mounted) setState(() => _isLoading = false);
    return;
  }

  try {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/forum/subtopics/$subtopicId/posts'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    print('Fetch Posts Response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200 && mounted) {
      setState(() {
        _posts = List<Map<String, dynamic>>.from(json.decode(response.body));
        _isLoading = false;
      });
    } else {
      showFailed(context, 'Failed to load posts: ${response.statusCode} - ${response.body}');
      if (mounted) setState(() => _isLoading = false);
    }
  } catch (e) {
    showFailed(context, 'Error fetching posts: $e');
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) {
      showWarning(context, 'Post content cannot be empty');
      return;
    }

    final token = await _authService.getToken();
    final subtopicId = widget.subtopic['id'];

    if (token == null || subtopicId == null) {
      showFailed(context, 'Authentication error');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/forum/subtopics/$subtopicId/posts'), // New endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'content': _postController.text.trim()}),
      );

      print('Create Post Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201) {
        showSuccess(context, 'Post created successfully');
        _postController.clear();
        await _fetchPosts();
      } else {
        showFailed(context, 'Failed to create post: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      showFailed(context, 'Error creating post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subtopic['title'] ?? 'Subtopic Details'),
        backgroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subtopic['description'] ?? 'No description', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Posted on: ${widget.subtopic['createdAt'] ?? 'N/A'} by ${widget.subtopic['username'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            const Text('Discussion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_isLoggedIn) ...[
              TextField(
                controller: _postController,
                decoration: InputDecoration(
                  labelText: 'Add a comment...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _createPost),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
            ],
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? const Text('No comments yet', style: TextStyle(color: Colors.grey))
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            final content = post['content'] ?? 'No content';
                            String formattedDate = 'N/A';
                            if (post['createdAt'] != null) {
                              try {
                                final parsedDate = DateTime.parse(post['createdAt']);
                                formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
                              } catch (e) {
                                print('Date parsing error: ${post['createdAt']} - $e');
                              }
                            }
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(content),
                                subtitle: Text('Posted on: $formattedDate by ${post['username'] ?? 'Unknown'}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
    _postController.dispose();
    super.dispose();
  }
}