import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
  final TextEditingController _reportReasonController = TextEditingController();
  final AuthService _authService = AuthService();
  int? _replyingToPostId;
  final Map<int, bool> _collapseStates = {};

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
      if (response.statusCode == 200 && mounted) {
        List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(json.decode(response.body));
        for (var post in posts) {
          final userId = post['userId'];
          post['upvoteCount'] ??= 0; // Ensure defaults
          post['downvoteCount'] ??= 0;
          post['userVote'] ??= null;
          if (userId != null) {
            try {
              final userResponse = await http.get(
                Uri.parse('https://localhost:7164/api/User/userdetails/$userId'),
                headers: {
                  if (token != null) 'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
              );
              if (userResponse.statusCode == 200) {
                final userData = json.decode(userResponse.body);
                post['profile_image_url'] = userData['profileImageUrl'] ?? '';
                post['signature'] = userData['signature'] ?? '';
              }
            } catch (e) {
              print('Error fetching user details for userId $userId: $e');
              post['profile_image_url'] = '';
              post['signature'] = '';
            }
          } else {
            post['profile_image_url'] = '';
            post['signature'] = '';
          }
        }
        setState(() {
          _posts = posts;
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
  final userIdStr = await _authService.getUserId();
  final subtopicId = widget.subtopic['id'];

  if (token == null || userIdStr == null || subtopicId == null) {
    showFailed(context, 'Authentication error');
    return;
  }

  final userId = int.tryParse(userIdStr);
  if (userId == null) {
    showFailed(context, 'Invalid user ID');
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/posts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
        'subtopicId': subtopicId,
        'content': _postController.text.trim(),
        'parentPostId': parentPostId,
      }),
    );

    if (response.statusCode == 201 && mounted) {
      showSuccess(context, 'Post created successfully');
      _postController.clear();
      setState(() => _replyingToPostId = null);
      await _fetchPosts(); // Refresh posts to display the new post
    } else if (mounted) {
      showFailed(context, 'Failed to create post: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    if (mounted) {
      showFailed(context, 'Error creating post: $e');
    }
  }
}

  Future<void> _reportPost(int postId) async {
    if (!_isLoggedIn) {
      showFailed(context, 'Please log in to report content');
      return;
    }
    final token = await _authService.getToken();
    final userIdStr = await _authService.getUserId();
    if (token == null || userIdStr == null) {
      showFailed(context, 'Authentication error');
      return;
    }
    int? userId = int.tryParse(userIdStr);
    if (userId == null) {
      showFailed(context, 'Invalid user ID');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Report Post', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _reportReasonController,
          decoration: InputDecoration(
            labelText: 'Reason for reporting (optional)',
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse('https://localhost:7164/api/Admin/report'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: json.encode({
                    'contentType': 'post',
                    'contentId': postId,
                    'reason': _reportReasonController.text.trim().isEmpty ? null : _reportReasonController.text.trim(),
                  }),
                );
                Navigator.pop(context);
                if (response.statusCode == 200 && mounted) {
                  showSuccess(context, 'Post reported. Thank you for your feedback.');
                  _reportReasonController.clear();
                } else if (mounted) {
                  String errorMessage = 'Failed to report post';
                  try {
                    final errorData = json.decode(response.body);
                    errorMessage = errorData['error'] ?? errorMessage;
                  } catch (_) {}
                  showFailed(context, errorMessage);
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) showFailed(context, 'Error reporting post: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _votePost(int postId, String voteType) async {
    if (!_isLoggedIn) {
      showFailed(context, 'Please log in to vote');
      return;
    }
    final token = await _authService.getToken();
    if (token == null) {
      showFailed(context, 'Authentication error');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/forum/posts/$postId/vote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'voteType': voteType}),
      );
      if (response.statusCode == 200 && mounted) {
        await _fetchPosts(); // Refresh posts to update vote counts
      } else if (mounted) {
        showFailed(context, 'Failed to vote: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) showFailed(context, 'Error voting: $e');
    }
  }

  Future<void> _removeVote(int postId) async {
    if (!_isLoggedIn) {
      showFailed(context, 'Please log in to remove vote');
      return;
    }
    final token = await _authService.getToken();
    if (token == null) {
      showFailed(context, 'Authentication error');
      return;
    }
    try {
      final response = await http.delete(
        Uri.parse('https://localhost:7164/api/forum/posts/$postId/vote'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 && mounted) {
        await _fetchPosts(); // Refresh posts to update vote counts
      } else if (mounted) {
        showFailed(context, 'Failed to remove vote: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) showFailed(context, 'Error removing vote: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(int userId) async {
    if (!_isLoggedIn) {
      showFailed(context, 'Please log in to view user details');
      return null;
    }
    final token = await _authService.getToken();
    if (token == null) {
      showFailed(context, 'Authentication error');
      return null;
    }
    try {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/User/userdetails/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        showFailed(context, 'Failed to load user details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      showFailed(context, 'Error fetching user details: $e');
      return null;
    }
  }

 void _showUserProfileDialog(Map<String, dynamic> userData) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 300, // Cube-like dimensions
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 40,
              backgroundImage: userData['profileImageUrl'] != null && userData['profileImageUrl'].isNotEmpty
                  ? NetworkImage(userData['profileImageUrl'])
                  : null,
              child: userData['profileImageUrl'] == null || userData['profileImageUrl'].isEmpty
                  ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                  : null,
              backgroundColor: Colors.grey[800],
            ),
            SizedBox(height: 12),
            // Username
            Text(
              userData['username'] ?? 'Unknown',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            // Data Fields
            if (userData['registrationDate'] != null) ...[
              _buildProfileField(
                icon: Icons.calendar_today,
                label: 'Joined',
                value: DateFormat('yyyy-MM-dd').format(DateTime.parse(userData['registrationDate'])),
              ),
              SizedBox(height: 12),
            ],
            if (userData['lastActivity'] != null) ...[
              _buildProfileField(
                icon: Icons.access_time,
                label: 'Last Active',
                value: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(userData['lastActivity'])),
              ),
              SizedBox(height: 12),
            ],
            if (userData['userRank'] != null && userData['userRank'].isNotEmpty) ...[
              _buildProfileField(
                icon: Icons.star,
                label: 'Rank',
                value: userData['userRank'],
              ),
              SizedBox(height: 12),
            ],
            if (userData['postCount'] != null) ...[
              _buildProfileField(
                icon: Icons.comment,
                label: 'Posts',
                value: '${userData['postCount']}',
              ),
              SizedBox(height: 12),
            ],
            if (userData['bio'] != null && userData['bio'].isNotEmpty) ...[
              _buildProfileField(
                icon: Icons.info,
                label: 'Bio',
                value: userData['bio'],
                isMultiLine: true,
              ),
              SizedBox(height: 12),
            ],
            if (userData['hobbies'] != null && (userData['hobbies'] as List).isNotEmpty) ...[
              _buildProfileField(
                icon: Icons.favorite,
                label: 'Hobbies',
                value: (userData['hobbies'] as List).join(', '),
                isMultiLine: true,
              ),
            ],
            SizedBox(height: 16),
            // Close Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.blueAccent, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper method to build profile fields
Widget _buildProfileField({
  required IconData icon,
  required String label,
  required String value,
  bool isMultiLine = false,
}) {
  return Row(
    crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
    children: [
      Icon(icon, color: Colors.blue, size: 20),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 14),
              maxLines: isMultiLine ? null : 1,
              overflow: isMultiLine ? null : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
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

Future<bool> _isOwnPost(int postUserId) async {
  final userIdStr = await _authService.getUserId();
  final loggedInUserId = userIdStr != null ? int.tryParse(userIdStr) : null;
  return loggedInUserId != null && postUserId == loggedInUserId;
}

Future<void> _deletePost(int postId) async {
  if (!_isLoggedIn) {
    showFailed(context, 'Please log in to delete posts');
    return;
  }

  final token = await _authService.getToken();
  final userIdStr = await _authService.getUserId();
  if (token == null || userIdStr == null) {
    showFailed(context, 'Authentication error');
    return;
  }

  final userId = int.tryParse(userIdStr);
  if (userId == null) {
    showFailed(context, 'Invalid user ID');
    return;
  }

  // Show confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Delete Post', style: TextStyle(color: Colors.white)),
      content: Text('Are you sure you want to delete this post?', style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != null && confirm && mounted) {
    try {
      final response = await http.delete(
        Uri.parse('https://localhost:7164/api/User/posts/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && mounted) {
        showSuccess(context, 'Post deleted successfully');
        await _fetchPosts(); // Refresh posts list
        Navigator.pop(context, true); // Signal refresh for AccountPage
      } else if (mounted) {
        showFailed(context, 'Failed to delete post: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        showFailed(context, 'Error deleting post: $e');
      }
    }
  }
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
  final postId = post['id'] as int;
  final upvoteCount = post['upvoteCount'] ?? 0;
  final downvoteCount = post['downvoteCount'] ?? 0;
  final userVote = post['userVote'] as String?;
  if (!_collapseStates.containsKey(postId)) {
    _collapseStates[postId] = false;
  }
  final isCollapsed = _collapseStates[postId]!;

  return Stack(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post['children'] != null && (post['children'] as List).isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _collapseStates[postId] = !isCollapsed;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.0 * depth, top: 8, right: 8),
                    child: Icon(
                      isCollapsed ? MdiIcons.plus : MdiIcons.minus,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                )
              else
                SizedBox(width: 16.0 * depth + (depth > 0 ? 10.0 : 0.0)),
              GestureDetector(
                onTap: () async {
                  final userId = post['userId'];
                  if (userId != null) {
                    final userDetails = await _fetchUserDetails(userId);
                    if (userDetails != null && mounted) {
                      _showUserProfileDialog(userDetails);
                    }
                  } else {
                    showFailed(context, 'User ID not available');
                  }
                },
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: post['profile_image_url'] != null && post['profile_image_url'].isNotEmpty
                        ? NetworkImage(post['profile_image_url'])
                        : null,
                    child: post['profile_image_url'] == null || post['profile_image_url'].isEmpty
                        ? Icon(Icons.person, size: 14, color: Colors.grey[400])
                        : null,
                    backgroundColor: Colors.grey[800],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 2,
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsets.only(
                    left: (depth > 0 ? 10.0 : 0.0),
                    top: 8,
                    bottom: 8,
                    right: 8,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    title: Text(
                      content,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            children: [
                              TextSpan(text: 'Posted on: '),
                              TextSpan(text: formattedDate),
                              TextSpan(text: ' by '),
                              TextSpan(
                                text: post['username'] ?? 'Unknown',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                color: userVote == 'upvote' ? Colors.green : Colors.grey[400],
                              ),
                              onPressed: userVote == 'upvote'
                                  ? () => _removeVote(postId)
                                  : () => _votePost(postId, 'upvote'),
                              tooltip: 'Upvote',
                            ),
                            Text('$upvoteCount', style: TextStyle(color: Colors.grey[400])),
                            SizedBox(width: 16),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                color: userVote == 'downvote' ? Colors.red : Colors.grey[400],
                              ),
                              onPressed: userVote == 'downvote'
                                  ? () => _removeVote(postId)
                                  : () => _votePost(postId, 'downvote'),
                              tooltip: 'Downvote',
                            ),
                            Text('$downvoteCount', style: TextStyle(color: Colors.grey[400])),
                            SizedBox(width: 16),
                            if (_isLoggedIn) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() => _replyingToPostId = post['id']);
                                },
                                child: Text('Reply', style: TextStyle(color: Colors.blueAccent)),
                              ),
                              FutureBuilder<bool>(
                                future: _isOwnPost(post['userId']),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data == true) {
                                    return TextButton(
                                      onPressed: () => _deletePost(postId),
                                      child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                    );
                                  }
                                  return SizedBox.shrink();
                                },
                              ),
                              Spacer(), // Pushes the Report button to the right
                              TextButton(
                                onPressed: () => _reportPost(post['id']),
                                child: Text('Report', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ],
                        ),
                        if (post['signature'] != null && post['signature'].isNotEmpty) ...[
                          SizedBox(height: 8),
                          Divider(color: Colors.grey[600]),
                          SizedBox(height: 8),
                          Text(
                            post['signature'],
                            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoggedIn && _replyingToPostId == post['id'])
            Padding(
              padding: EdgeInsets.only(left: 16.0 * (depth + 1) + 10.0, right: 16),
              child: TextField(
                controller: _postController,
                decoration: InputDecoration(
                  labelText: 'Reply to this comment...',
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: () => _createPost(parentPostId: post['id']),
                  ),
                ),
                style: TextStyle(color: Colors.white),
                maxLines: 3,
              ),
            ),
          if (!isCollapsed && post['children'] != null)
            ...((post['children'] as List<Map<String, dynamic>>).map((child) => _buildPostItem(child, depth: depth + 1))),
        ],
      ),
      if (depth > 0) ...[
        Positioned(
          left: 16.0 * (depth - 1) + 4.0,
          top: 0,
          bottom: null,
          height: 30.0,
          child: Container(
            width: 2,
            color: Colors.grey[600],
          ),
        ),
        Positioned(
          left: 16.0 * (depth - 1) + 4.0,
          top: 30.0,
          width: 16.0,
          child: Container(
            height: 2,
            color: Colors.grey[600],
          ),
        ),
        if (!isCollapsed && post['children'] != null && (post['children'] as List).isNotEmpty)
          Positioned(
            left: 16.0 * (depth - 1) + 4.0,
            top: 30.0,
            bottom: 0,
            child: Container(
              width: 2,
              color: Colors.grey[600],
            ),
          ),
      ],
    ],
  );
}
@override
Widget build(BuildContext context) {
  final topLevelPosts = _buildPostTree(_posts);
  final String imagePath = 'assets/pictures/backgroundimage.png'; // Hardcoded background image

  return Scaffold(
    body: Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5), // Updated opacity to 0.5
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) {
              // Fallback gradient if image fails to load
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade900,
                      Colors.blueGrey.shade700,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              );
            },
          ),
        ),
        // Content
        Column(
          children: [
            // Custom Title Bar with Back Button
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueGrey.shade900,
                    Colors.blueGrey.shade700,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      widget.subtopic['title'] ?? 'Subtopic Details',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance the back button
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 3,
                      color: Colors.blueGrey.shade900.withOpacity(0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          widget.subtopic['description'] ?? 'No description',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[200],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Posted on: ${widget.subtopic['createdAt'] != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(widget.subtopic['createdAt'])) : 'N/A'}${widget.subtopic['username'] != null ? ' by ${widget.subtopic['username']}' : ''}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Discussion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoggedIn && _replyingToPostId == null) ...[
                      TextField(
                        controller: _postController,
                        decoration: InputDecoration(
                          labelText: 'Add a comment...',
                          filled: true,
                          fillColor: Colors.blueGrey.shade700,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send, color: Colors.tealAccent),
                            onPressed: () => _createPost(),
                          ),
                          labelStyle: TextStyle(color: Colors.grey[400]),
                        ),
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                        : topLevelPosts.isEmpty
                            ? Text('No comments yet', style: TextStyle(color: Colors.grey[400]))
                            : Expanded(
                                child: ListView.builder(
                                  itemCount: topLevelPosts.length,
                                  itemBuilder: (context, index) => _buildPostItem(topLevelPosts[index]),
                                ),
                              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

@override
void dispose() {
  _postController.dispose();
  _reportReasonController.dispose();
  super.dispose();
}
}
