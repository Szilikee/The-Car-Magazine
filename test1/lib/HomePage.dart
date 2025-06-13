import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'ListingDetails.dart';
import 'auth_service.dart';
import 'main.dart';
import 'ForumPage.dart';
import 'Models.dart';
import 'Translations.dart';


class HomePage extends StatefulWidget {
  final String selectedLanguage;

  const HomePage({super.key, required this.selectedLanguage});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _recentTopics = [];
  List<Car> _recentCars = [];

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
          _recentCars = data.map((carJson) => Car.fromJson(carJson)).take(6).toList(); // Limit to 5 cars
        });
      }
    } catch (e) {
      print('Error fetching cars: $e');
    }
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6), // Dark overlay for readability
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    translations[widget.selectedLanguage]!['welcome']!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your ultimate destination for car enthusiasts!',
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

            // Featured Car Listings Section
            Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.5), // Add overlay for readability
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    height: 400,
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
                ],
              ),
            ),

            // Recent Forum Posts Section
            Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.5), // Add overlay for readability
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
              ),
            ),

            // View More Button
            Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.5), // Add overlay for readability
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ForumPage(selectedLanguage: "en",)),
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
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildFeaturedCarCard(Car car) {
  return Container(
    width: 280,
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
     child: InkWell(
      onTap: () {
        // Navigáció az autó részleteihez a ListingDetailsPage-re
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListingDetailsPage(car: car), // Átadjuk a teljes Car objektumot
          ),
        );
      },
    
    child: Card(
      elevation: 6,
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Colors.white, // Add a subtle border with the new color
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              car.imagePath.isNotEmpty
                  ? car.imagePath
                  : 'https://via.placeholder.com/250x120',
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
    ),),
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
      leading: const Icon(
        Icons.forum,
        color: Colors.blue, // Update icon color to deep orange
        size: 36,
      ),
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
          MaterialPageRoute(builder: (context) => MainPage(authService: AuthService())),
        );
      },
    ),
  );
}
}
