import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'SubTopicDetailsPage.dart';
import 'CreateSubTopicPage.dart';

class TopicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> topic;

  const TopicDetailsPage({super.key, required this.topic});

  @override
  _TopicDetailsPageState createState() => _TopicDetailsPageState();
}

class _TopicDetailsPageState extends State<TopicDetailsPage> {
  List<Map<String, dynamic>> _subtopics = [];
  List<Map<String, dynamic>> _filteredSubtopics = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchSubtopics();
    _searchController.addListener(_filterSubtopics);
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _authService.isUserLoggedIn();
    if (mounted) setState(() => _isLoggedIn = loggedIn);
  }

  Future<void> _fetchSubtopics() async {
    final topicId = widget.topic['id'];
    print('Fetching subtopics for Topic ID: $topicId');
    if (topicId == null) {
      showFailed(context, 'Invalid topic ID');
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
          _subtopics.sort((a, b) {
            final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
            final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
            return dateB.compareTo(dateA);
          });
          _filteredSubtopics = _subtopics;
          _isLoading = false;
        });
      } else {
        showFailed(context, 'Failed to load subtopics: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      showFailed(context, 'Error fetching subtopics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSubtopics() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubtopics = _subtopics.where((subtopic) {
        final title = subtopic['title']?.toString().toLowerCase() ?? '';
        return title.contains(query);
      }).toList();
    });
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
            Text(
              'Category: ${widget.topic['category'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.topic['description'] ?? 'No description',
              style: const TextStyle(fontSize: 25),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtopics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isLoggedIn)
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateSubtopicPage(topicId: widget.topic['id']),
                        ),
                      );
                      if (result == true) {
                        _fetchSubtopics();
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Create New Subtopic',
                      style: TextStyle(fontSize: 14),
                      selectionColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search subtopics...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubtopics.isEmpty
                    ? const Text('No subtopics found', style: TextStyle(color: Colors.grey))
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _filteredSubtopics.length,
                          itemBuilder: (context, index) {
                            final subtopic = _filteredSubtopics[index];
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
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                title: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Posted on: $formattedDate by ${subtopic['username'] ?? 'Unknown'}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
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
    _searchController.dispose();
    super.dispose();
  }
}

void showFailed(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}

void showWarning(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.orange),
  );
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.green),
  );
}