import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main.dart';
import 'ForumPage.dart';

class HomePage extends StatefulWidget {
  final String selectedLanguage;

  const HomePage({super.key, required this.selectedLanguage});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _recentTopics = [];
  List<Car> _recentCars = [];

  static const Map<String, Map<String, String>> translations = {
    'en': {
      'welcome': 'Welcome to The Car Magazin!',
      'featuredCars': 'Featured Car Listings',
      'recentPosts': 'Recent Forum Posts',
      'viewMore': 'View More',
    },
    'hu': {
      'welcome': 'Üdvözöljük az Autó Magazinban!',
      'featuredCars': 'Kiemelt Autó Hirdetések',
      'recentPosts': 'Legutóbbi Fórum Bejegyzések',
      'viewMore': 'Továbbiak Megtekintése',
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchRecentTopics();
    _fetchRecentCars();
  }

  Future<void> _fetchRecentTopics() async {
    try {
      final response = await http.get(Uri.parse('https://localhost:7164/api/forum/topics'));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _recentTopics = List<Map<String, dynamic>>.from(json.decode(response.body))
              .take(3)
              .toList(); // Limit to 3 recent posts
        });
      } else {
        print('Error fetching topics: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception during fetchTopics: $e');
    }
  }

  Future<void> _fetchRecentCars() async {
    const String apiUrl = 'https://localhost:7164/api/marketplace/carlistings';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _recentCars = data.map((carJson) => Car.fromJson(carJson)).take(5).toList(); // Limit to 5 cars
        });
      } else {
        print('Failed to load cars: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching cars: $e');
    }
  }

  Future<String> _getCarImageFromAPI(String carName) async {
    final apiKey = dotenv.env['PEXELS_API_KEY'];
    final apiUrl = 'https://api.pexels.com/v1/search?query=${Uri.encodeComponent(carName)}&per_page=1';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': apiKey!},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['photos'][0]['src']['original'];
      }
    } catch (e) {
      print('Error fetching image: $e');
    }
    return 'https://via.placeholder.com/250x120';
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey.shade900, // Consistent dark background
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center the content horizontally
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center the content vertically
              crossAxisAlignment: CrossAxisAlignment.center, // Center the text horizontally
              children: [
                Text(
                  translations[widget.selectedLanguage]!['welcome']!,
                  style: const TextStyle(
                    fontSize: 24, // Smaller font size
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center, // Center the text
                ),
                const SizedBox(height: 12),
                Text(
                  'Your ultimate destination for car enthusiasts!',
                  style: TextStyle(
                    fontSize: 14, // Smaller font size
                    color: Colors.white.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center, // Center the text
                        ),
                      ],
                    ),
                  ),

            // Featured Car Listings Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
              height: 280,
              child: _recentCars.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _recentCars.length,
                      itemBuilder: (context, index) {
                        return _buildFeaturedCarCard(_recentCars[index]);
                      },
                    ),
            ),

            // Recent Forum Posts Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                translations[widget.selectedLanguage]!['recentPosts']!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            _recentTopics.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: _recentTopics
                          .map((topic) => _buildForumPostCard(context, topic))
                          .toList(),
                    ),
                  ),

            // View More Button
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MainPage()),
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
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to ForumPage when tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ForumPage()),
                      );
                    },
                    child: Text(
                      translations[widget.selectedLanguage]!['viewMore']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCarCard(Car car) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 6,
        color: Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: FutureBuilder<String>(
                future: _getCarImageFromAPI(car.title),
                builder: (context, snapshot) {
                  return Image.network(
                    snapshot.data ?? 'https://via.placeholder.com/250x120',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.network(
                      'https://via.placeholder.com/250x120',
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  );
                },
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
                      fontSize: 18,
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
    );
  }

  Widget _buildForumPostCard(BuildContext context, Map<String, dynamic> topic) {
    final title = topic['topic'] ?? 'N/A';
    final description = topic['description'] ?? 'No description';
    String formattedDate = 'N/A';

    final createdAt = topic['createdAt'];
    if (createdAt != null) {
      try {
        final parsedDate = DateTime.parse(createdAt.toString());
        formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(parsedDate);
      } catch (e) {
        formattedDate = 'Invalid Date';
      }
    }

    return Card(
      elevation: 4,
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.forum, color: Colors.blueAccent, size: 36),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MainPage()),
          ); // Adjust to navigate to TopicDetailsPage if available
        },
      ),
    );
  }
}

// Car class from MarketplacePage
class Car {
  final String title;
  final int year;
  final int price;
  final int mileage;
  final String fuel;
  final String imagePath;
  final String location;
  final String transmission;
  final String owner;

  Car({
    required this.title,
    required this.year,
    required this.price,
    required this.mileage,
    required this.fuel,
    required this.imagePath,
    required this.location,
    required this.transmission,
    required this.owner,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      title: json['name'] ?? 'Unknown Car',
      year: json['year'] ?? 0,
      price: json['sellingPrice'] ?? 0,
      mileage: json['kmDriven'] ?? 0,
      fuel: json['fuel'] ?? 'Unknown',
      imagePath: json['imageUrl'] ?? '',
      location: json['sellerType'] ?? 'Unknown',
      transmission: json['transmission'] ?? 'Unknown',
      owner: json['owner']?.trim() ?? 'Unknown',
    );
  }
}