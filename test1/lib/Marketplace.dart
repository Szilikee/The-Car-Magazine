import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'CreateListingPage.dart';
import 'auth_service.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  _MarketplacePageState createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  late Future<List<Car>> _carsFuture;
  bool isLoggedIn = false;
  String statusMessage = '';
  List<Car> allCars = [];
  List<Car> filteredCars = [];
  int currentPage = 0;
  final int itemsPerPage = 12;

  // Filter variables
  String searchKeyword = '';
  bool showFilters = false; // Új változó a szűrők megjelenítéséhez
  bool usePriceFilter = false;
  TextEditingController minPriceController = TextEditingController();
  TextEditingController maxPriceController = TextEditingController();
  bool useMileageFilter = false;
  TextEditingController minMileageController = TextEditingController();
  TextEditingController maxMileageController = TextEditingController();
  bool useYearFilter = false;
  TextEditingController minYearController = TextEditingController();
  TextEditingController maxYearController = TextEditingController();
  bool useFuelFilter = false;
  String? selectedFuel;
  bool useSellerTypeFilter = false;
  String? selectedSellerType;
  bool useTransmissionFilter = false;
  String? selectedTransmission;
  bool useOwnerFilter = false;
  TextEditingController ownerController = TextEditingController();

  // Lista az ismert értékekhez (API adatok alapján)
  final List<String> fuelOptions = ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'asd'];
  final List<String> sellerTypeOptions = ['Individual', 'Dealer', 'asd', 'En'];
  final List<String> transmissionOptions = ['Manual', 'Automatic', 'asd'];

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    _loadCars();
  }

  @override
  void dispose() {
    minPriceController.dispose();
    maxPriceController.dispose();
    minMileageController.dispose();
    maxMileageController.dispose();
    minYearController.dispose();
    maxYearController.dispose();
    ownerController.dispose();
    super.dispose();
  }

  void checkLoginStatus() async {
    bool status = await AuthService().isUserLoggedIn();
    setState(() {
      isLoggedIn = status;
    });
  }

  void _loadCars() {
    setState(() {
      _carsFuture = getCars();
    });
  }

  Future<List<Car>> getCars() async {
    const String apiUrl = 'https://localhost:7164/api/forum/carlistings';
    final String? token = await AuthService().getToken();
    try {
      print('Fetching cars from: $apiUrl');
      print('Token: $token');
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Car> cars = data.map((carJson) {
          if (carJson['imageUrl'] == null) print('Warning: imageUrl is null for car: ${carJson['name']}');
          if (carJson['sellingPrice'] == 0) print('Warning: sellingPrice is 0 for car: ${carJson['name']}');
          if (carJson['sellerType'] == null || carJson['sellerType'] == '') print('Warning: sellerType is empty for car: ${carJson['name']}');
          return Car.fromJson(carJson);
        }).toList();
        print('Parsed cars: $cars');
        setState(() {
          allCars = cars;
          filteredCars = cars;
          statusMessage = cars.isEmpty ? 'No cars found' : '';
        });
        return cars;
      } else {
        setState(() {
          statusMessage = 'Failed to load cars: ${response.statusCode} - ${response.body}';
        });
        print('API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Network error: $e';
      });
      print('Network error: $e');
      return [];
    }
  }

  void _filterCars() {
    setState(() {
      filteredCars = allCars.where((car) {
        bool matchesSearch = searchKeyword.isEmpty ||
            car.title.toLowerCase().contains(searchKeyword.toLowerCase()) ||
            car.year.toString().contains(searchKeyword.trim());

        bool matchesPrice = true;
        if (usePriceFilter) {
          double minPrice = double.tryParse(minPriceController.text) ?? 0;
          double maxPrice = double.tryParse(maxPriceController.text) ?? double.infinity;
          matchesPrice = (car.price == 0 && minPrice == 0) ||
              (car.price >= minPrice && car.price <= maxPrice);
        }

        bool matchesMileage = true;
        if (useMileageFilter) {
          double minMileage = double.tryParse(minMileageController.text) ?? 0;
          double maxMileage = double.tryParse(maxMileageController.text) ?? double.infinity;
          matchesMileage = (car.mileage == 0 && minMileage == 0) ||
              (car.mileage >= minMileage && car.mileage <= maxMileage);
        }

        bool matchesYear = true;
        if (useYearFilter) {
          int minYear = int.tryParse(minYearController.text) ?? 0;
          int maxYear = int.tryParse(maxYearController.text) ?? 9999;
          matchesYear = car.year >= minYear && car.year <= maxYear;
        }

        bool matchesFuel = true;
        if (useFuelFilter && selectedFuel != null) {
          matchesFuel = car.fuel.toLowerCase() == selectedFuel!.toLowerCase();
        }

        bool matchesSellerType = true;
        if (useSellerTypeFilter && selectedSellerType != null) {
          matchesSellerType = car.location.toLowerCase() == selectedSellerType!.toLowerCase();
        }

        bool matchesTransmission = true;
        if (useTransmissionFilter && selectedTransmission != null) {
          matchesTransmission = car.transmission.toLowerCase() == selectedTransmission!.toLowerCase();
        }

        bool matchesOwner = true;
        if (useOwnerFilter && ownerController.text.isNotEmpty) {
          matchesOwner = car.owner.toLowerCase().contains(ownerController.text.toLowerCase());
        }

        return matchesSearch &&
            matchesPrice &&
            matchesMileage &&
            matchesYear &&
            matchesFuel &&
            matchesSellerType &&
            matchesTransmission &&
            matchesOwner;
      }).toList();

      currentPage = 0;
      statusMessage = filteredCars.isEmpty ? 'No cars match the filters' : '';
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
        // Gombok vízszintes sorban
// Gombok vízszintes sorban, felcserélve
if (isLoggedIn || true)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              showFilters = !showFilters;
            });
          },
          child: Text(showFilters ? 'Hide Filters' : 'Show Filters'),
        ),
        if (isLoggedIn)
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateCarListingsPage()),
              ).then((_) => _loadCars());
            },
            child: const Text('Add New Car Listing'),
          ),
      ],
    ),
  ),


        // Szűrők
        if (showFilters)
          Container(
            padding: const EdgeInsets.all(10.0),
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Keresőmező (mindig látható, külön)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      onChanged: (text) {
                        searchKeyword = text;
                        _filterCars();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name or year...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  // Ár szűrő
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: usePriceFilter,
                              onChanged: (value) {
                                setState(() {
                                  usePriceFilter = value ?? false;
                                });
                                _filterCars();
                              },
                            ),
                            const Text('Price (€)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minPriceController,
                                enabled: usePriceFilter,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Min',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => _filterCars(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxPriceController,
                                enabled: usePriceFilter,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => _filterCars(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Futásteljesítmény szűrő
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: useMileageFilter,
                              onChanged: (value) {
                                setState(() {
                                  useMileageFilter = value ?? false;
                                });
                                _filterCars();
                              },
                            ),
                            const Text('Mileage (km)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minMileageController,
                                enabled: useMileageFilter,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Min',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => _filterCars(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxMileageController,
                                enabled: useMileageFilter,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => _filterCars(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Év szűrő
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: useYearFilter,
                              onChanged: (value) {
                                setState(() {
                                  useYearFilter = value ?? false;
                                });
                                _filterCars();
                              },
                            ),
                            const Text('Year', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minYearController,
                                enabled: useYearFilter,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Min',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => _filterCars(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxYearController,
                                enabled: useYearFilter,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => _filterCars(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // További szűrők ugyanígy kialakítva
                ],
              ),
            ),
          ),
        // Autók listája
        Expanded(
          child: FutureBuilder<List<Car>>(
            future: _carsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return Center(child: Text('No cars available: $statusMessage'));
              } else {
                return PaginatedCarList(
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
                );
              }
            },
          ),
        ),
      ],
    ),
  );
}
}
// PaginatedCarList és Car osztály változatlan
class PaginatedCarList extends StatelessWidget {
  final List<Car> cars;
  final int currentPage;
  final int itemsPerPage;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;

  const PaginatedCarList({
    super.key,
    required this.cars,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onNextPage,
    required this.onPreviousPage,
  });

  @override
  Widget build(BuildContext context) {
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, cars.length);
    final pageCars = cars.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: pageCars.length,
            itemBuilder: (context, index) {
              final car = pageCars[index];
              final imageUrl = car.imagePath.isNotEmpty
                  ? car.imagePath
                  : 'https://t3.ftcdn.net/jpg/02/48/42/64/360_F_248426448_NVKLywWqArG2ADUxDq6QprtIzsF82dMF.jpg';

              print('Loading image for ${car.title}: $imageUrl');

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
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Image load error for ${car.title}: $error');
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(child: Text('Image not available')),
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
                            '${car.title} (${car.year})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${car.fuel} • ${car.mileage} km • ${car.transmission}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            '${car.price} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: currentPage > 0 ? onPreviousPage : null,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 16),
              Text('Page ${currentPage + 1}'),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: (currentPage + 1) * itemsPerPage < cars.length ? onNextPage : null,
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
    print('Parsing JSON: $json');
    return Car(
      title: json['name']?.toString() ?? 'Unknown Car',
      year: json['year']?.toInt() ?? 0,
      price: (json['sellingPrice']?.toDouble() ?? json['selling_price']?.toDouble() ?? 0).toInt(),
      mileage: json['kmDriven']?.toInt() ?? json['km_driven']?.toInt() ?? 0,
      fuel: json['fuel']?.toString() ?? 'Unknown',
      imagePath: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      location: json['sellerType']?.toString() ?? json['seller_type']?.toString() ?? 'Unknown',
      transmission: json['transmission']?.toString() ?? 'Unknown',
      owner: json['owner']?.toString().trim() ?? 'Unknown',
    );
  }

  @override
  String toString() => 'Car(title: $title, year: $year, price: $price, imagePath: $imagePath)';
}