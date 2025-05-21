import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'auth_service.dart';

class SubtopicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> subtopic;

  const SubtopicDetailsPage({super.key, required this.subtopic});

  @override
  _SubtopicDetailsPageState createState() => _SubtopicDetailsPageState();
}

class _SubtopicDetailsPageState extends State<SubtopicDetailsPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final TextEditingController _postController = TextEditingController();
  final AuthService _authService = AuthService();
  int? _replyingToPostId;

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

 Future<void> _createPost({int? parentPostId}) async {
    if (_postController.text.trim().isEmpty) {
        showWarning(context, 'Post content cannot be empty');
        return;
    }

    final token = await _authService.getToken();
    final subtopicId = widget.subtopic['id'];

    print('Creating post for Subtopic ID: $subtopicId, Content: ${_postController.text.trim()}, ParentPostId: $parentPostId');
    print('Token for CreatePost: $token');

    if (token == null || subtopicId == null) {
        showFailed(context, 'Authentication error');
        return;
    }

    try {
        final response = await http.post(
            Uri.parse('https://localhost:7164/api/forum/topics/$subtopicId/posts'), // Helyes URL
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
            },
            body: json.encode({
                'content': _postController.text.trim(),
                'parentPostId': parentPostId,
            }),
        );

        print('Create Post Response: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 201 && mounted) {
            showSuccess(context, 'Post created successfully');
            _postController.clear();
            setState(() => _replyingToPostId = null);
            await _fetchPosts();
        } else if (mounted) {
            showFailed(context, 'Failed to create post: ${response.statusCode} - ${response.body}');
        }
    } catch (e) {
        if (mounted) {
            showFailed(context, 'Error creating post: $e');
        }
    }

}

  List<Map<String, dynamic>> _buildPostTree(List<Map<String, dynamic>> posts) {
    final Map<int, List<Map<String, dynamic>>> children = {};
    final List<Map<String, dynamic>> topLevelPosts = [];

    for (var post in posts) {
      final postId = post['id'] as int;
      children[postId] = [];
    }

    for (var post in posts) {
      final parentPostId = post['parentPostId'] as int?;
      if (parentPostId == null) {
        topLevelPosts.add(post);
      } else {
        children[parentPostId]?.add(post);
      }
    }

    for (var post in posts) {
      final postId = post['id'] as int;
      post['children'] = children[postId] ?? [];
    }

    return topLevelPosts;
  }

 Widget _buildPostItem(Map<String, dynamic> post, {int depth = 0}) {
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

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        elevation: 2,
        margin: EdgeInsets.only(left: 16.0 * depth, top: 8, bottom: 8, right: 8),
        child: ListTile(
          title: Text(content),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Posted on szöveg RichText-tel, hogy a username fehér legyen
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  children: [
                    const TextSpan(text: 'Posted on: '),
                    TextSpan(text: formattedDate),
                    const TextSpan(text: ' by '),
                    TextSpan(
                      text: post['username'] ?? 'Unknown', // Helyes username a post objektumból
                      style: const TextStyle(color: Colors.white), // Fehér szín a névhez
                    ),
                  ],
                ),
              ),
              if (_isLoggedIn)
                TextButton(
                  onPressed: () {
                    setState(() => _replyingToPostId = post['id']);
                  },
                  child: const Text('Reply'),
                ),
            ],
          ),
        ),
      ),
      if (_isLoggedIn && _replyingToPostId == post['id'])
        Padding(
          padding: EdgeInsets.only(left: 16.0 * (depth + 1), right: 8),
          child: TextField(
            controller: _postController,
            decoration: InputDecoration(
              labelText: 'Reply to this comment...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _createPost(parentPostId: post['id']),
              ),
            ),
            maxLines: 3,
          ),
        ),
      if (post['children'] != null)
        ...((post['children'] as List<Map<String, dynamic>>).map((child) => _buildPostItem(child, depth: depth + 1))),
    ],
  );
}
  @override
Widget build(BuildContext context) {
  final topLevelPosts = _buildPostTree(_posts);

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.subtopic['title'] ?? 'Subtopic Details'),
      backgroundColor: Colors.black87,
      elevation: 4,
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leírás kártya közvetlenül a cím alatt
          Card(
            elevation: 3,
            color: Colors.grey[900], // Sötét háttér a modern megjelenéshez
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                widget.subtopic['description'] ?? 'No description',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.4, // Több sortávolság a jobb olvashatóság érdekében
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Posted on információ
          Text(
            'Posted on: ${widget.subtopic['createdAt'] != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(widget.subtopic['createdAt'])) : 'N/A'}${widget.subtopic['username'] != null ? ' by ${widget.subtopic['username']}' : ''}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          // Discussion szekció
          const Text(
            'Discussion',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_isLoggedIn && _replyingToPostId == null) ...[
            TextField(
              controller: _postController,
              decoration: InputDecoration(
                labelText: 'Add a comment...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _createPost(),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
          ],
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : topLevelPosts.isEmpty
                  ? const Text('No comments yet', style: TextStyle(color: Colors.grey))
                  : Expanded(
                      child: ListView.builder(
                        itemCount: topLevelPosts.length,
                        itemBuilder: (context, index) => _buildPostItem(topLevelPosts[index]),
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

void showFailed(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}

void showWarning(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
}