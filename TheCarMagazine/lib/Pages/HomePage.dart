import 'package:carousel_slider/carousel_slider.dart' as carousel_slider;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_car_forum/Pages/MagazinePage.dart';
import 'ListingDetails.dart';
import '../Models/Models.dart';
import '../Utils/Translations.dart';
import '../Pages/ArticleDetailsPage.dart';

class HomePage extends StatefulWidget {
  final String selectedLanguage;

  const HomePage({super.key, required this.selectedLanguage});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _recentArticles = [];
  List<Car> _recentCars = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final List<AnimationController> _articleControllers = [];
  static const int maxArticleCards = 10;

  // Hibakód ellenőrző változók
  final TextEditingController _errorCodeController = TextEditingController();
  Map<String, String> _errorCodes = {};

  @override
  void initState() {
    super.initState();
    _articleControllers.clear();
    for (int i = 0; i < maxArticleCards; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + (i * 200)),
        vsync: this,
      )..forward();
      _articleControllers.add(controller);
    }
    _fetchRecentTopics();
    _fetchRecentArticles();
    _fetchRecentCars();
    _loadErrorCodes();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  // JSON betöltése az assets mappából
  Future<void> _loadErrorCodes() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(context).loadString('assets/dtcmapping.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        _errorCodes = jsonData.map((key, value) => MapEntry(key, value.toString()));
      });
    } catch (e) {
      _showErrorSnackBar('Hiba a hibakódok betöltésekor: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    for (var controller in _articleControllers) {
      controller.dispose();
    }
    _errorCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentTopics() async {
    try {
      final response = await http.get(Uri.parse('https://localhost:7164/api/forum/topics'));
      if (response.statusCode == 200 && mounted) {
        setState(() {
        });
      } else {
        _showErrorSnackBar('Failed to fetch forum topics: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching topics: $e');
    }
  }

  Future<void> _fetchRecentArticles() async {
    try {
      final response = await http.get(Uri.parse('https://localhost:7164/api/magazine/articles'));
      if (response.statusCode == 200 && mounted) {
        List<dynamic> articles = json.decode(response.body);
        List<Map<String, dynamic>> fetchedArticles = List<Map<String, dynamic>>.from(articles);
        while (fetchedArticles.length < maxArticleCards) {
          fetchedArticles.add({
            'title': 'Dummy Article ${fetchedArticles.length + 1}',
            'imageUrl': 'https://via.placeholder.com/150',
          });
        }
        setState(() {
          _recentArticles = fetchedArticles.take(maxArticleCards).toList();
        });
      } else {
        _showErrorSnackBar('Failed to fetch articles: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching articles: $e');
    }
  }

  Future<void> _fetchRecentCars() async {
    const String apiUrl = 'https://localhost:7164/api/marketplace/carlistings';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _recentCars = data.map((carJson) => Car.fromJson(carJson)).take(6).toList();
        });
      } else {
        _showErrorSnackBar('Failed to fetch cars: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching cars: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Hibakód ellenőrző logika
  void _checkErrorCode() {
    final code = _errorCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            translations[widget.selectedLanguage]!['error'] ?? 'Hiba',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: Text(
            translations[widget.selectedLanguage]!['error_empty_code'] ?? 'Kérlek, adj meg egy hibakódot!',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                translations[widget.selectedLanguage]!['cancel'] ?? 'Mégse',
                style: const TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final description = _errorCodes[code];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          description != null
              ? translations[widget.selectedLanguage]!['error_code'] ?? 'Hibakód'
              : translations[widget.selectedLanguage]!['error_unknown_code'] ?? 'Hiba',
          style: TextStyle(
            color: description != null ? Colors.blueAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          description != null
              ? '${translations[widget.selectedLanguage]!['error_code'] ?? 'Hibakód'}: $code - $description'
              : '${translations[widget.selectedLanguage]!['unknown_code'] ?? 'Ismeretlen hibakód'} ($code)',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              translations[widget.selectedLanguage]!['cancel'] ?? 'Mégse',
              style: const TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
    _errorCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/pictures/backgroundimage.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Welcome Section
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
Text(
  translations[widget.selectedLanguage]!['welcome']!,
  style: const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.normal, // Luxurious Roman csak Regular stílust támogat
    color: Colors.white,
    letterSpacing: 1.2,
    fontFamily: 'LuxuriousRoman',
  ),

                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        translations[widget.selectedLanguage]!['welcome_subtitle'] ?? 'Your ultimate destination for car enthusiasts!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Magazine Articles Section
Container(
  width: double.infinity,
  color: Colors.black.withOpacity(0.5),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(
          translations[widget.selectedLanguage]!['recentArticles'] ?? 'Legutóbbi cikkek',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      SizedBox(
        height: 400,
        child: _recentArticles.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : carousel_slider.CarouselSlider(
                options: carousel_slider.CarouselOptions(
                  height: 400,
                  viewportFraction: 0.15,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 3),
                  enlargeCenterPage: true,
                  scrollDirection: Axis.horizontal,
                  initialPage: 0,
                  enlargeStrategy: carousel_slider.CenterPageEnlargeStrategy.height,
                  pageSnapping: true,
                ),
                items: _recentArticles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final article = entry.value;
                  return _buildMagazineArticleCard(context, article, index);
                }).toList(),
              ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_scaleAnimation.value * 0.1),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MagazinePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    translations[widget.selectedLanguage]!['viewMore'] ?? 'Továbbiak',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  ),
),

              // Forum Posts Section
              //_buildForumSection(context, _recentTopics),

              // Car Listings Section
            Container(
  width: double.infinity,
  color: Colors.black.withOpacity(0.5),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Text(
          translations[widget.selectedLanguage]!['featuredCars']!,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      SizedBox(
        height: 400,
        child: _recentCars.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Feltételezzük, hogy minden kártya szélessége fix, pl. 200 pixel
                  const spacing = 12.0; // Kártyák közötti távolság

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(left: 40, right: 12),
                    itemCount: _recentCars.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: spacing),
                        child: _buildFeaturedCarCard(_recentCars[index]),
                      );
                    },
                  );
                },
              ),
      ),
    ],
  ),
),

              // Hibakód Ellenőrző Szekció
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        translations[widget.selectedLanguage]!['error_code_checker'] ?? 'Hibakód Ellenőrző',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _errorCodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: translations[widget.selectedLanguage]!['enter_error_code'] ?? 'Add meg a hibakódot (pl. P0001)',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blueAccent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _checkErrorCode(),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_scaleAnimation.value * 0.05),
                            child: ElevatedButton(
                              onPressed: _checkErrorCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              child: Text(
                                translations[widget.selectedLanguage]!['check'] ?? 'Ellenőrzés',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCarCard(Car car) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListingDetailsPage(car: car),
                  ),
                );
              },
              child: Card(
                elevation: 6,
                color: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        car.imagePath.isNotEmpty ? car.imagePath : 'https://via.placeholder.com/250x120',
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.network(
                          'https://via.placeholder.com/250x120',
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${car.title} - ${car.year}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${car.mileage} km • ${car.transmission}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${car.price} €',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /*Widget _buildForumSection(BuildContext context, List<Map<String, dynamic>> topics) {
    return Container(
      width: double.infinity,
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              translations[widget.selectedLanguage]!['recentPosts']!,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_scaleAnimation.value * 0.1),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ForumPage(selectedLanguage: widget.selectedLanguage),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        translations[widget.selectedLanguage]!['viewMore']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
*/
  Widget _buildMagazineArticleCard(BuildContext context, Map<String, dynamic> article, int index) {
    final title = article['title'] ?? 'N/A';
    final imageUrl = article['imageUrl'] ?? 'https://via.placeholder.com/150';

    final controller = _articleControllers[index];
    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );

    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) {
            setState(() {
              isHovered = true;
            });
          },
          onExit: (_) {
            setState(() {
              isHovered = false;
            });
          },
          child: Container(
            width: 250,
            height: 650,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: isHovered ? scaleAnimation.value * 1.15 : scaleAnimation.value,
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArticleDetailPage(
                              article: article,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.network(
                                  'https://via.placeholder.com/150',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: Colors.black.withOpacity(0.7),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
/*
class _OrbitCardLayout extends StatefulWidget {
  final List<Map<String, dynamic>> topics;
  final String selectedLanguage;

  const _OrbitCardLayout({
    required this.topics,
    required this.selectedLanguage,
  });

  @override
  __OrbitCardLayoutState createState() => __OrbitCardLayoutState();
}

class __OrbitCardLayoutState extends State<_OrbitCardLayout> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  List<AnimationController> _cardControllers = [];
  double _rotationAngle = 0.0;
  double _dragStartAngle = 0.0;
  double _dragStartX = 0.0;
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    for (int i = 0; i < widget.topics.length; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + (i * 100)),
        vsync: this,
      )..forward();
      _cardControllers.add(controller);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _cardControllers.clear();
    super.dispose();
  }

  void _updateRotation(double dx) {
    final delta = dx / 200;
    setState(() {
      _rotationAngle += delta;
      _focusedIndex = ((_rotationAngle / (2 * math.pi / widget.topics.length)) % widget.topics.length).round();
      if (_focusedIndex < 0) _focusedIndex += widget.topics.length;
    });
  }

  void _snapToNearest() {
    final targetAngle = (_focusedIndex * (2 * math.pi / widget.topics.length));
    _rotationController.reset();
    _rotationController.animateTo(
      (targetAngle - _rotationAngle) / (2 * math.pi),
      curve: Curves.easeOut,
    ).then((_) {
      setState(() {
        _rotationAngle = targetAngle;
      });
    });
  }

/*  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        _dragStartX = details.localPosition.dx;
        _dragStartAngle = _rotationAngle;
      },
      onHorizontalDragUpdate: (details) {
        final dx = details.localPosition.dx - _dragStartX;
        _updateRotation(-dx);
      },
      onHorizontalDragEnd: (details) {
        _snapToNearest();
      },
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(widget.topics.length, (index) {
          final angle = _rotationAngle + (index * (2 * math.pi / widget.topics.length));
          final isFocused = index == _focusedIndex;
          final radius = isFocused ? 120.0 : 100.0;
          final scale = isFocused ? 1.2 : 0.8;
          final opacity = isFocused ? 1.0 : 0.6;

          final x = radius * math.cos(angle);
          final y = radius * math.sin(angle) * 0.3;

          return AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(x, y),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: _buildOrbitCard(context, widget.topics[index], index, isFocused),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildOrbitCard(BuildContext context, Map<String, dynamic> topic, int index, bool isFocused) {
    final title = topic['topic'] ?? 'N/A';
    final description = topic['description'] ?? 'No description';
    String formattedDate = 'N/A';
    if (topic['createdAt'] != null) {
      try {
        final parsedDate = DateTime.parse(topic['createdAt'].toString());
        formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        formattedDate = 'Invalid Date';
      }
    }

    final controller = _cardControllers[index];
    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );
    final fadeAnimation = CurvedAnimation(parent: controller, curve: Curves.easeIn);

    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedBuilder(
            animation: Listenable.merge([scaleAnimation, fadeAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: fadeAnimation,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ForumPage(selectedLanguage: widget.selectedLanguage),
                      ),
                    );
                  },
                  child: Container(
                    width: isFocused ? 250 : 150,
                    height: isFocused ? 200 : 120,
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isHovered || isFocused
                            ? [Colors.grey.shade700, Colors.blueGrey.shade600]
                            : [Colors.grey.shade900, Colors.grey.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(isHovered || isFocused ? 0.4 : 0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(isHovered || isFocused ? 0.7 : 0.5),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isFocused)
                                  const Icon(
                                    Icons.forum,
                                    color: Colors.blueAccent,
                                    size: 20,
                                  ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: isFocused ? 18 : 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (isFocused) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isFocused)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }*/
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class InvertedTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final offset = width * 0.2;

    path.moveTo(offset, 0);
    path.lineTo(width - offset, 0);
    path.lineTo(width, height * 0.3);
    path.lineTo(width, height * 0.7);
    path.lineTo(width - offset, height);
    path.lineTo(offset, height);
    path.lineTo(0, height * 0.7);
    path.lineTo(0, height * 0.3);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}*/


class MagazinePageMock extends StatelessWidget {
  final String selectedLanguage;

  const MagazinePageMock({super.key, required this.selectedLanguage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          translations[selectedLanguage]!['magazine'] ?? 'Magazin',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black.withOpacity(0.6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Vissza navigálás az előző oldalra
          },
        ),
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/pictures/backgroundimage.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Text(
            translations[selectedLanguage]!['noData'] ?? 'Magazin tartalom hamarosan',
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}