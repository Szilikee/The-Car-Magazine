import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'CreateListingPage.dart';
import 'auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MarketplacePage extends StatefulWidget {
  @override
  _MarketplacePageState createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  late Future<List<Car>> _cars;
  bool isLoggedIn = false;
  String statusMessage = '';
  List<Car> allCars = [];
  List<Car> filteredCars = [];
  int currentPage = 0;
  final int itemsPerPage = 12;

  // Filter variables
  String searchKeyword = '';
  double minPrice = 0;
  double maxPrice = 10000000;
  double minMileage = 0;
  double maxMileage = 3000000;
  String? selectedTransmission;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    _loadCars();
    _updateMaxValues();
  }

  void checkLoginStatus() async {
    bool status = await AuthService().isUserLoggedIn();
    setState(() {
      isLoggedIn = status;
    });
  }

  void _loadCars() {
    setState(() {
      _cars = getCars();
    });
  }

Future<List<Car>> getCars() async {
  const String apiUrl = 'https://localhost:7164/api/marketplace/carlistings'; // Changed from localhost

  try {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      List<Car> cars = data.map((carJson) => Car.fromJson(carJson)).toList();
      allCars = cars;
      filteredCars = cars;
      return cars;
    } else {
      throw Exception('Failed to load cars: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    setState(() {
      statusMessage = 'Error loading data: $e';
    });
    throw Exception('Error fetching data: $e');
  }
}

  Future<String> getCarImageFromAPI(String carName) async {
    final apiKey = dotenv.env['PEXELS_API_KEY']; // Kulcs betöltése
    final apiUrl = 'https://api.pexels.com/v1/search?query=${Uri.encodeComponent(carName)}&per_page=1';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': apiKey!}, // Használat
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['photos'][0]['src']['original']; // Kép URL visszaadása
      } else {
        throw Exception('Failed to fetch image, Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching image: $e');
      return 'https://via.placeholder.com/150'; // Ha hiba történik
    }
  }

void _updateMaxValues() {
  if (allCars.isNotEmpty) {
    setState(() {
      maxPrice = allCars.map((car) => car.price).reduce((a, b) => a > b ? a : b).toDouble();
      maxMileage = allCars.map((car) => car.mileage).reduce((a, b) => a > b ? a : b).toDouble();

      // Ha az aktuális értékek kívül esnek az új min-max tartományon, akkor állítsuk vissza őket
      if (minPrice > maxPrice) minPrice = 0;
      if (maxPrice == 0) maxPrice = 10000000; // Default maximum, ha nincs adat

      if (minMileage > maxMileage) minMileage = 0;
      if (maxMileage == 0) maxMileage = 30000000; // Default maximum, ha nincs adat
    });
  }
}


void _filterCars() {
  setState(() {
    filteredCars = allCars.where((car) {
      bool matchesName = car.title.toLowerCase().contains(searchKeyword.toLowerCase());
      bool matchesYear = car.year.toString().contains(searchKeyword);

      bool matchesSearch = searchKeyword.isEmpty || matchesName || matchesYear;
      bool matchesPrice = car.price >= minPrice && car.price <= maxPrice;
      bool matchesMileage = car.mileage >= minMileage && car.mileage <= maxMileage;
      bool matchesTransmission = selectedTransmission == null || car.transmission == selectedTransmission;

      return matchesSearch && matchesPrice && matchesMileage && matchesTransmission;
    }).toList();
  });
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Marketplace'),
      ),
      body: Column(
        children: [
          // Feltételesen megjelenő gomb a bejelentkezett felhasználóknak
          if (isLoggedIn)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateCarListingsPage()),
                  );
                },
                child: const Text('Add New Car Listing'),
              ),
            ),
          // Hibakezelés
          if (statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(statusMessage),
            ),
          // Szűrők
          Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar for Car Brand
              TextField(
                onChanged: (text) {
                  setState(() {
                    searchKeyword = text;
                  });
                  _filterCars();
                },
                decoration: InputDecoration(
                  hintText: 'Search for cars...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Szűrők egymás mellett (Row)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dropdown for Transmission
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transmission:', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            hint: Text('Transmission'),
                            value: selectedTransmission,
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedTransmission = newValue;
                              });
                              _filterCars();
                            },
                            items: ['Automatic', 'Manual']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Price Range Slider
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price Range (€):', style: TextStyle(fontWeight: FontWeight.bold)),
                          RangeSlider(
                            values: RangeValues(minPrice, maxPrice),
                            min: 0,
                            max: 10000000,
                            divisions: 20,
                            labels: RangeLabels('${minPrice.toInt()} €', '${maxPrice.toInt()} €'),
                            onChanged: (RangeValues values) {
                              setState(() {
                                minPrice = values.start;
                                maxPrice = values.end;
                              });
                              _filterCars();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Mileage Range Slider
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mileage Range (km):', style: TextStyle(fontWeight: FontWeight.bold)),
                          RangeSlider(
                            values: RangeValues(minMileage, maxMileage),
                            min: 0,
                            max: 3000000,
                            divisions: 30,
                            labels: RangeLabels('${minMileage.toInt()} km', '${maxMileage.toInt()} km'),
                            onChanged: (RangeValues values) {
                              setState(() {
                                minMileage = values.start;
                                maxMileage = values.end;
                              });
                              _filterCars();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

          // Paginált lista
          Expanded(
            child: PaginatedCarList(
              cars: filteredCars,
              currentPage: currentPage,
              itemsPerPage: itemsPerPage,
              onNextPage: () {
                setState(() {
                  if ((currentPage + 1) * itemsPerPage < filteredCars.length) {
                    currentPage++;
                  }
                });
              },
              onPreviousPage: () {
                setState(() {
                  if (currentPage > 0) {
                    currentPage--;
                  }
                });
              },
              getCarImageFromAPI: getCarImageFromAPI, // Passing the method here
            ),
          ),
        ],
      ),
    );
  }
}

class PaginatedCarList extends StatelessWidget {
  final List<Car> cars;
  final int currentPage;
  final int itemsPerPage;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final Future<String> Function(String) getCarImageFromAPI; // Method to fetch images

  const PaginatedCarList({
    required this.cars,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.getCarImageFromAPI, // Accepting method here
  });

  @override
  Widget build(BuildContext context) {
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (currentPage + 1) * itemsPerPage;
    final pageCars = cars.sublist(startIndex, endIndex < cars.length ? endIndex : cars.length);

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6, // Kevesebb oszlop a szép megjelenés érdekében
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: pageCars.length,
            itemBuilder: (context, index) {
              final car = pageCars[index];

              return FutureBuilder<String>(
                future: getCarImageFromAPI(car.title), // Using the method passed as parameter
                builder: (context, imageSnapshot) {
                  if (imageSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (imageSnapshot.hasError) {
                    return Center(child: Text('Error fetching image'));
                  }

                  // Kép URL
                  String imageUrl = imageSnapshot.data ?? 'https://via.placeholder.com/150';

                  return Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.network(
                                  'https://via.placeholder.com/150',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${car.title} - ${car.year}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${car.fuel} - ${car.mileage} km - ${car.transmission}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '${car.price} €',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Lapozás
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onPreviousPage,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: onNextPage,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
      imagePath: json['imageUrl'] ?? '', // Update image path if necessary
      location: json['sellerType'] ?? 'Unknown',
      transmission: json['transmission'] ?? 'Unknown',
      owner: json['owner']?.trim() ?? 'Unknown',
    );
  }
}
