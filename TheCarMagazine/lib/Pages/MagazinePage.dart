import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../Services/auth_service.dart';
import 'ArticleDetailsPage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MagazinePage extends StatefulWidget {
  const MagazinePage({super.key});

  @override
  _MagazinePageState createState() => _MagazinePageState();
}

class _MagazinePageState extends State<MagazinePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;
  String? _userRole;
  int? _userId;
  bool _showAddArticleForm = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  PlatformFile? _selectedImage;
  String _selectedPlacement = 'list';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fetchUserRole();
    _fetchArticles().then((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        print('No auth token found. User is likely not logged in.');
        setState(() {
          _userRole = 'user';
          _userId = null;
        });
        return;
      }

      final userIdStr = await authService.getUserId();
      final userId = int.tryParse(userIdStr ?? '');
      if (userId == null) {
        print('No user ID found in SharedPreferences.');
        setState(() {
          _userRole = 'user';
          _userId = null;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://localhost:7164/api/User/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final userData = json.decode(response.body);
        if (userData == null || userData['id'] == null || userData['role'] == null) {
          print('Invalid user data: $userData');
          setState(() {
            _userRole = 'user';
            _userId = userId;
          });
          return;
        }
        setState(() {
          _userRole = userData['role'].toString();
          _userId = int.tryParse(userData['id'].toString()) ?? userId;
        });
      } else {
        print('Error fetching user role: ${response.statusCode} - ${response.body}');
        setState(() {
          _userRole = 'user';
          _userId = userId;
        });
      }
    } catch (e) {
      print('Exception during fetchUserRole: $e');
      setState(() {
        _userRole = 'user';
        _userId = null;
      });
    }
  }

  Future<void> _fetchArticles() async {
    try {
      final response = await http.get(Uri.parse('https://localhost:7164/api/magazine/articles'));
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> fetchedArticles = json.decode(response.body);
        setState(() {
          _articles = fetchedArticles.map((article) {
            final map = article as Map<String, dynamic>;
            return {...map, 'isHovered': false};
          }).toList();
          _articles.sort((a, b) {
            const placementOrder = {'featured': 0, 'grid': 1, 'list': 2};
            return placementOrder[a['placement'] ?? 'list']!.compareTo(
                placementOrder[b['placement'] ?? 'list']!);
          });
          _isLoading = false;
        });
      } else {
        print('Error fetching articles: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Exception during fetchArticles: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name.toLowerCase();
        if (fileName.endsWith('.jpg') ||
            fileName.endsWith('.jpeg') ||
            fileName.endsWith('.png') ||
            fileName.endsWith('.webp')) {
          setState(() {
            _selectedImage = file;
            print('Selected image: ${_selectedImage!.name}, Bytes: ${_selectedImage!.bytes?.length}, Path: ${_selectedImage!.path}');
          });
        } else {
          print('Invalid file type selected: $fileName');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only JPG, JPEG, PNG, or WEBP files are allowed')),
          );
        }
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<String?> _uploadImageToCloudinary(PlatformFile image) async {
    const cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dshksou7u/image/upload';
    const uploadPreset = 'marketplace_preset';

    try {
      print('Starting Cloudinary upload for image: ${image.name}');
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        if (image.bytes != null) {
          print('Web: Uploading image with ${image.bytes!.length} bytes');
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              image.bytes!,
              filename: image.name,
            ),
          );
        } else {
          print('Web: No bytes available for image ${image.name}');
          return null;
        }
      } else {
        if (image.path != null) {
          print('Mobile: Uploading image from path ${image.path}');
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              image.path!,
            ),
          );
        } else {
          print('Mobile: No path available for image ${image.name}');
          return null;
        }
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      print('Cloudinary response: ${response.statusCode} - $responseBody');

      if (response.statusCode == 200) {
        var jsonData = json.decode(responseBody);
        if (jsonData['secure_url'] != null) {
          print('Cloudinary upload successful: ${jsonData['secure_url']}');
          return jsonData['secure_url'];
        } else {
          print('Cloudinary response missing secure_url: $jsonData');
          return null;
        }
      } else {
        print('Cloudinary upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<void> _addArticle() async {
    if (_titleController.text.isEmpty || _categoryController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image')),
      );
      return;
    }

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not available')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? imageUrl = await _uploadImageToCloudinary(_selectedImage!);
    if (imageUrl == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image')),
      );
      return;
    }

    final articleData = {
      'UserId': _userId,
      'Title': _titleController.text,
      'Description': _descriptionController.text,
      'ImageUrl': imageUrl,
      'Category': _categoryController.text,
      'Placement': _selectedPlacement,
      'CreatedAt': DateTime.now().toIso8601String(),
      'LastUpdatedAt': DateTime.now().toIso8601String(),
    };
    final requestBody = json.encode(articleData);

    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not available')),
        );
        return;
      }

      final uri = Uri.parse('https://localhost:7164/api/magazine/articles');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      if (response.statusCode == 201) {
        await _fetchArticles();
        _titleController.clear();
        _descriptionController.clear();
        _categoryController.clear();
        setState(() {
          _selectedImage = null;
          _showAddArticleForm = false;
          _selectedPlacement = 'list';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Article added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add article: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding article')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAddArticleForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Article',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPlacement,
                decoration: const InputDecoration(
                  labelText: 'Placement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'featured', child: Text('Featured (Top Large Article)')),
                  DropdownMenuItem(value: 'grid', child: Text('Grid (One of Five Cards)')),
                  DropdownMenuItem(value: 'list', child: Text('List (Horizontal Cards)')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPlacement = value ?? 'list';
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedImage == null ? 'No image selected' : 'Image: ${_selectedImage!.name}',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Select Image'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAddArticleForm = false;
                        _titleController.clear();
                        _descriptionController.clear();
                        _categoryController.clear();
                        _selectedImage = null;
                        _selectedPlacement = 'list';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _addArticle,
                    child: const Text('Add Article'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 600;
    final String imagePath = 'assets/pictures/backgroundimage.png';

    final Map<String, dynamic> featuredArticle = _articles.isNotEmpty
        ? _articles.firstWhere(
            (article) => article['placement'] == 'featured',
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final gridArticles = _articles.where((article) => article['placement'] == 'grid').take(5).toList();
    final listArticles = _articles.where((article) => article['placement'] == 'list').toList();


    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) {
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
          Column(
            children: [
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
                    Expanded(
                      child: Text(
                        'Magazine',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    _userRole == 'admin'
                        ? IconButton(
                            icon: const Icon(Icons.add, color: Colors.tealAccent, size: 28),
                            onPressed: () {
                              setState(() {
                                _showAddArticleForm = !_showAddArticleForm;
                              });
                            },
                            tooltip: 'Add New Article',
                          )
                        : const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_showAddArticleForm) _buildAddArticleForm(),
                              if (featuredArticle.isNotEmpty)
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: _buildFeatureArticleCard(
                                      title: featuredArticle['title'] ?? 'No Title',
                                      imageUrl: featuredArticle['imageUrl'] ?? '',
                                      article: featuredArticle,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (gridArticles.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: _buildArticleGrid(isMobile: isMobile, gridArticles: gridArticles),
                                ),
                              const SizedBox(height: 10),
                              if (listArticles.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: listArticles.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      var article = entry.value;
                                      return FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: Offset(0, 0.2 * (index + 1)),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: _animationController,
                                              curve: Interval(
                                                0.1 * index.clamp(0, 9),
                                                1.0,
                                                curve: Curves.easeInOut,
                                              ),
                                            ),
                                          ),
                                          child: _buildHorizontalArticleCard(
                                            title: article['title'] ?? 'No Title',
                                            description: article['description'] ?? 'No description',
                                            imageUrl: article['imageUrl'] ?? '',
                                            isMobile: isMobile,
                                            article: article,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArticleGrid({required bool isMobile, required List<Map<String, dynamic>> gridArticles}) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: gridArticles.asMap().entries.map((entry) {
        int index = entry.key;
        var article = entry.value;
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.2 * (index + 1)),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (0.1 * index).clamp(0.0, 0.9),
                  1.0,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            child: _buildSmallArticleCard(
              title: article['title'] ?? 'No Title',
              imageUrl: article['imageUrl'] ?? '',
              isMobile: isMobile,
              article: article,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSmallArticleCard({
    required String title,
    required String imageUrl,
    required bool isMobile,
    required Map<String, dynamic> article,
  }) {
    return _HoverableCard(
      isMobile: isMobile,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(article: article),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/150',
                fit: BoxFit.cover,
                height: isMobile ? 75 : 275,
                width: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Szöveg olvashatósága miatt
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalArticleCard({
    required String title,
    required String description,
    required String imageUrl,
    required bool isMobile,
    required Map<String, dynamic> article,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: isMobile ? 150 : 200),
      child: _HoverableCard(
        isMobile: isMobile,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailPage(article: article),
            ),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Konzisztens a grid kártyákkal
          ),
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 5,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/150',
                  fit: BoxFit.cover,
                  height: isMobile ? 150 : 200,
                  width: isMobile ? 120 : 300,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Szöveg olvashatósága miatt
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.white, // Szöveg olvashatósága miatt
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureArticleCard({
    required String title,
    required String imageUrl,
    required Map<String, dynamic> article,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(article: article),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Konzisztens a többivel
        ),
        elevation: 5,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double height = constraints.maxWidth < 600 ? 200 : 350;
            print('FeatureArticleCard constraints: ${constraints.maxWidth}x${constraints.maxHeight}');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/150',
                    fit: BoxFit.cover,
                    height: height,
                    width: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.tealAccent),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HoverableCard extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onTap;
  final Widget child;

  const _HoverableCard({
    required this.isMobile,
    required this.onTap,
    required this.child,
  });

  @override
  __HoverableCardState createState() => __HoverableCardState();
}

class __HoverableCardState extends State<_HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.isMobile
          ? (_) => setState(() => _isHovered = true)
          : null,
      onTapUp: widget.isMobile
          ? (_) => setState(() => _isHovered = false)
          : null,
      onTapCancel: widget.isMobile
          ? () => setState(() => _isHovered = false)
          : null,
      child: MouseRegion(
        onEnter: widget.isMobile
            ? null
            : (_) => setState(() => _isHovered = true),
        onExit: widget.isMobile
            ? null
            : (_) => setState(() => _isHovered = false),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12), // Lekerekített sarkok
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Colors.tealAccent.withOpacity(0.6) // Domináns szín hovernél
                      : Colors.transparent, // Átlátszó alapállapotban
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.6 : 0.2), // Erős árnyék hovernél
                      blurRadius: _isHovered ? 20 : 6, // Nagyobb blur hovernél
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}