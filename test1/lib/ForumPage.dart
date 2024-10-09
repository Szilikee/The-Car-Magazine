import 'package:flutter/material.dart';
//import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


class ForumPage extends StatefulWidget {
  const ForumPage({Key? key}) : super(key: key);

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedYear;

  List<String> _brands = [];
  List<String> _models = [];
  List<String> _years = [];
  List<Map<String, dynamic>> _topics = []; // Minden téma
  List<Map<String, dynamic>> _filteredTopics = []; // Szűrt témák
  String _searchQuery = ''; // Keresési kifejezés

  @override
  void initState() {
    super.initState();
    fetchBrands(); // Márkák lekérése
    fetchTopics(); // Témák lekérése
  }

  // Márkák lekérése az API-ból
  Future<void> fetchBrands() async {
    final response = await http.get(Uri.parse('https://localhost:7164/api/forum/brands'));
    if (response.statusCode == 200) {
      setState(() {
        _brands = List<String>.from(json.decode(response.body));
        _brands.sort(); // Rendezzük a márkákat ábécé sorrendbe
      });
    }
  }

  // Modellek lekérése a kiválasztott márkához
  Future<void> fetchModels(String brand) async {
    final response = await http.get(Uri.parse('https://localhost:7164/api/forum/models/$brand'));
    if (response.statusCode == 200) {
      setState(() {
        _models = List<String>.from(json.decode(response.body));
        _selectedModel = null; // Reset the model selection
        _years.clear(); // Clear the years as well
        _models.sort();
      });
    }
  }

// Évjáratok lekérése a kiválasztott márkához és modellhez
Future<void> fetchYears(String brand, String model) async {
  try {
    final response = await http.get(Uri.parse('https://localhost:7164/api/forum/years/$brand/$model'));
    if (response.statusCode == 200) {
      setState(() {
        _years = List<String>.from(json.decode(response.body));
        _selectedYear = null; // Reset the year selection
        _years.sort();
      });
    } else {
      // Hibakezelés
      print('Hiba történt az évjáratok lekérése közben: ${response.statusCode}');
    }
  } catch (e) {
    // Hiba kezelése, ha a hívás nem sikerül
    print('Hiba történt a fetchYears metódusban: $e');
  }
}



  // Témák lekérése az API-ból
  Future<void> fetchTopics() async {
    final response = await http.get(Uri.parse('https://localhost:7164/api/forum/topics'));
    if (response.statusCode == 200) {
      setState(() {
        _topics = List<Map<String, dynamic>>.from(json.decode(response.body));
        _filteredTopics = List.from(_topics); // Az összes téma alapértelmezett szűrő
      });
    } else {
      // Hibakezelés
      print('Hiba történt a fórum témák lekérése közben');
    }
  }

  // Témák keresése
  void _filterTopics(String query) {
    setState(() {
      _searchQuery = query;
      if (_searchQuery.isNotEmpty) {
        _filteredTopics = _topics.where((topic) {
          final topicTitle = topic['topic']?.toLowerCase() ?? '';
          return topicTitle.contains(_searchQuery.toLowerCase());
        }).toList();
      } else {
        _filteredTopics = List.from(_topics); // Vissza az összes témához
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilterDropdowns(),
            const SizedBox(height: 20), // Térköz a dropdown és a keresőmező között
            _buildSearchField(),
            const SizedBox(height: 10), // Térköz a keresőmező és a lista között
            _buildFeaturedText(), // "Featured" szöveg
            const SizedBox(height: 10), // Térköz a "Featured" szöveg és a lista között
            Expanded(
              child: _buildTopicsList(), // Betöltött témák listája
            ),
          ],
        ),
      ),
    );
  }

// Keresőmező építése
Widget _buildSearchField() {
  return TextField(
    onChanged: _filterTopics,
    decoration: InputDecoration(
      hintText: 'Search topics...',
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue), // Kék szegély inaktív állapotban
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueAccent), // Kék szegély aktív állapotban
      ),
      suffixIcon: const Icon(Icons.search),
    ),
  );
}


  // "Featured" szöveg építése
  Widget _buildFeaturedText() {
    return Text(
      'Featured Topics',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  // Fórum témák listájának építése
  Widget _buildTopicsList() {
    return ListView.builder(
      itemCount: _filteredTopics.length,
      itemBuilder: (context, index) {
        // Téma adatok
        final topic = _filteredTopics[index]['topic'] ?? 'N/A';
        final description = _filteredTopics[index]['description'] ?? 'Nincs leírás';

        // Dátum formázása
        final createdAtRaw = _filteredTopics[index]['created_at'];
        String formattedDate = 'N/A';
        if (createdAtRaw != null) {
          try {
            DateTime parsedDate = DateTime.parse(createdAtRaw);
            formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
          } catch (e) {
            print('Dátum hiba: $createdAtRaw');
          }
        }

        return Card(
          elevation: 2, // Árnyék a kártyának
          margin: EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Icon(Icons.forum, color: Colors.blueAccent), // Fórum ikon
            title: Text(
              topic,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description), // Leírás
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formattedDate, // Formázott dátum megjelenítése
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
            onTap: () {
              // Téma részleteinek megjelenítése (ha van ilyen funkció)
            },
          ),
        );
      },
    );
  }

  // Dinamikus dropdown építése
  Widget _buildFilterDropdowns() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Dropdownok elosztása
      children: [
        Expanded(
          child: _buildDropdown<String>(
            value: _selectedBrand,
            hint: 'Select Brand',
            items: _brands,
            onChanged: (value) {
              setState(() {
                _selectedBrand = value;
                _selectedModel = null; // Reset model
                _selectedYear = null; // Reset year
                fetchModels(value!); // Betölti a modelleket a kiválasztott márkához
              });
            },
          ),
        ),
        const SizedBox(width: 8), // Térköz a dropdownok között
        Expanded(
          child: _buildDropdown<String>(
            value: _selectedModel,
            hint: 'Select Model',
            items: _models,
            onChanged: (value) {
              setState(() {
                _selectedModel = value;
                _selectedYear = null; // Reset year
                if (value != null) { // Ellenőrizd, hogy a value nem null
                  fetchYears(_selectedBrand!, value); // Helyes metódus hívás
                }
              });
            },
          ),
        ),
        const SizedBox(width: 8), // Térköz a dropdownok között
        Expanded(
          child: _buildDropdown<String>(
            value: _selectedYear,
            hint: 'Select Year',
            items: _years,
            onChanged: (value) {
              setState(() {
                _selectedYear = value;
              });
            },
          ),
        ),
      ],
    );
  }

  // Általános dropdown építő metódus
  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0), // Térköz a dropdownok között
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent), // Szegély színe
      ),
      constraints: BoxConstraints(maxWidth: 300), // Maximális szélesség beállítása
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(hint),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent), // Ikon
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Padding(
                padding: const EdgeInsets.all(10.0), // Padding a listaelemek körül
                child: Text(item.toString()),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}