import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../Services/auth_service.dart';
import '../Utils/Translations.dart';
import 'dart:io' show File;

class CreateSubtopicPage extends StatefulWidget {
  final int topicId;
  final String selectedLanguage;

  const CreateSubtopicPage({
    super.key,
    required this.topicId,
    required this.selectedLanguage,
  });

  @override
  _CreateSubtopicPageState createState() => _CreateSubtopicPageState();
}

class _CreateSubtopicPageState extends State<CreateSubtopicPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  String? _topicTitle;
  bool _isLoading = false;
  List<XFile?> _images = [null, null, null];
  List<Uint8List?> _imageBytes = [null, null, null];
  List<String?> _imageUrls = [null, null, null];
  List<bool> _isUploadingImages = [false, false, false];
  ScaffoldMessengerState? _scaffoldMessenger; // Store ScaffoldMessenger reference

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context); // Capture ScaffoldMessenger
  }

  @override
  void initState() {
    super.initState();
    _fetchTopic();
  }

  Future<void> _fetchTopic() async {
    try {
      final uri = Uri.parse('https://localhost:7164/api/forum/topics/${widget.topicId}');
      final response = await http.get(uri);

      if (response.statusCode == 200 && mounted) {
        final topic = jsonDecode(response.body);
        setState(() {
          _topicTitle = topic['topic'];
        });
      } else if (mounted) {
        _showSnackBar('failedToFetchTopic', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('errorFetchingTopic', isError: true, error: e.toString());
      }
    }
  }

  Future<void> _pickImage(int index) async {
    if (index < 0 || index >= 3) return;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        Uint8List? bytes;
        if (kIsWeb) {
          bytes = await pickedFile.readAsBytes();
        }
        setState(() {
          _images[index] = pickedFile;
          _imageUrls[index] = null;
          _imageBytes[index] = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('errorPickingImage', isError: true, error: e.toString());
      }
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile? image, int index) async {
    if (image == null) return null;

    setState(() => _isUploadingImages[index] = true);

    const String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dshksou7u/image/upload';
    const String apiKey = '156576676194584';
    const String uploadPreset = 'marketplace_preset';

    try {
      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['api_key'] = apiKey
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          await image.readAsBytes(),
          filename: image.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', image.path));
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(responseData);
        return jsonData['secure_url'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('errorUploadingImage', isError: true, error: e.toString());
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImages[index] = false);
      }
    }
  }

 Future<void> _createSubtopic() async {
  final title = _titleController.text.trim();
  final description = _descriptionController.text.trim();
  final token = await _authService.getToken();

  if (title.isEmpty || description.isEmpty) {
    _showSnackBar('fillAllFields', isWarning: true);
    return;
  }

  if (title.length < 5) {
    _showSnackBar('titleTooShort', isWarning: true);
    return;
  }

  if (description.length < 50) {
    _showSnackBar('descriptionTooShort', isWarning: true);
    return;
  }

  if (title.length > 255) {
    _showSnackBar('titleTooLong', isWarning: true);
    return;
  }

  if (token == null) {
    _showSnackBar('loginRequired', isError: true);
    return;
  }

  setState(() => _isLoading = true);

  try {
    for (var i = 0; i < _images.length; i++) {
      if (_images[i] != null && _imageUrls[i] == null) {
        _imageUrls[i] = await _uploadImageToCloudinary(_images[i], i);
        if (_imageUrls[i] == null && mounted) {
          _showSnackBar('failedToUploadImage', isError: true, error: 'Image ${i + 1}');
          setState(() => _isLoading = false);
          return;
        }
      }
    }

    final uri = Uri.parse('https://localhost:7164/api/forum/topics/${widget.topicId}/subtopics');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'imageUrl1': _imageUrls[0],
        'imageUrl2': _imageUrls[1],
        'imageUrl3': _imageUrls[2],
      }),
    );

    if (response.statusCode == 201 && mounted) {
      _showSnackBar('subtopicCreated');
      final responseBody = jsonDecode(response.body);
      final subtopicId = responseBody['id'];
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _images = [null, null, null];
        _imageBytes = [null, null, null];
        _imageUrls = [null, null, null];
      });
      Navigator.pop(context, subtopicId);
    } else if (mounted) {
      _showSnackBar('failedToCreateSubtopic', isError: true, error: response.statusCode.toString());
    }
  } catch (e) {
    if (mounted) {
      _showSnackBar('errorCreatingSubtopic', isError: true, error: e.toString());
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  void _showSnackBar(String key, {bool isError = false, bool isWarning = false, String? error}) {
    if (!mounted || _scaffoldMessenger == null) return; // Prevent access if disposed
    final t = translations[widget.selectedLanguage] ?? translations['en']!;
    final message = error != null ? '${t[key]}: $error' : t[key] ?? key;

    _scaffoldMessenger!.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError
            ? Colors.red
            : isWarning
                ? Colors.orange
                : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ... (rest of the code remains the same, including _buildImage

  @override
  Widget build(BuildContext context) {
    final t = translations[widget.selectedLanguage] ?? translations['en']!;
    const String imagePath = 'assets/pictures/backgroundimage.png';

    return Scaffold(
      body: Stack(
        children: [
          // Háttérkép
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) => Container(
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
              ),
            ),
          ),
          // Tartalom
          Column(
            children: [
              // Egyéni címsor
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
                      tooltip: t['back'] ?? 'Back',
                    ),
                    Expanded(
                      child: Text(
                        _topicTitle != null
                            ? '${t['createSubtopicFor'] ?? 'Create Subtopic for'} $_topicTitle'
                            : t['createNewSubtopic'] ?? 'Create New Subtopic',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Fő tartalom
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _titleController,
                          label: t['subtopicTitle'] ?? 'Subtopic Title',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          label: t['description'] ?? 'Description',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          t['uploadImages'] ?? 'Upload Images (Optional)',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildImageUploadFields(),
                        const SizedBox(height: 20),
                        Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                                )
                              : ElevatedButton(
                                  onPressed: _createSubtopic,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: Text(
                                    t['createSubtopic'] ?? 'Create Subtopic',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.blueGrey.shade700,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

 Widget _buildImageUploadFields() {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: List.generate(3, (index) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _images[index] != null
                ? Stack(
                    children: [
                      Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.memory(
                                  _imageBytes[index]!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                )
                              : Image.file(
                                  File(_images[index]!.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                ),
                        ),
                      ),
                      if (_isUploadingImages[index])
                        const Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.tealAccent,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              _images[index] = null;
                              _imageBytes[index] = null;
                              _imageUrls[index] = null;
                            });
                          },
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image, color: Colors.grey, size: 50),
                  ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _pickImage(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                '${t['pickImage'] ?? 'Pick Image'} ${index + 1}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}