import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'CreateListingPage.dart';
import 'ListingDetails.dart';
import 'auth_service.dart';
import 'Models.dart';
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
  bool showFilters = false;
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
  TextEditingController contactController = TextEditingController();

  // Filter options
  final List<String> fuelOptions = ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'LPG'];
  final List<String> sellerTypeOptions = ['Individual', 'Dealer'];
  final List<String> transmissionOptions = ['Manual', 'Automatic'];

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
    contactController.dispose();
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
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Car> cars = data.map((carJson) {
          if (carJson['imageUrl'] == null) print('Warning: imageUrl is null for car: ${carJson['name']}');
          if (carJson['sellingPrice'] == null || carJson['sellingPrice'] == 0) print('Warning: sellingPrice is 0 for car: ${carJson['name']}');
          if (carJson['sellerType'] == null || carJson['sellerType'] == '') print('Warning: sellerType is empty for car: ${carJson['name']}');
          return Car.fromJson(carJson);
        }).toList();
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
          matchesSellerType = car.sellerType.toLowerCase() == selectedSellerType!.toLowerCase();
        }

        bool matchesTransmission = true;
        if (useTransmissionFilter && selectedTransmission != null) {
          matchesTransmission = car.transmission.toLowerCase() == selectedTransmission!.toLowerCase();
        }

        bool matchesOwner = true;
        if (useOwnerFilter && contactController.text.isNotEmpty) {
          matchesOwner = car.contact.toLowerCase().contains(contactController.text.toLowerCase());
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
    final String imagePath = 'assets/pictures/backgroundimage.png';

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
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
          // Content
          Column(
            children: [
              // Custom Title Bar
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Car Marketplace',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
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
                  child: Column(
                    children: [
                      // Buttons Row
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Add New Car Listing'),
                              ),
                          ],
                        ),
                      ),
                      // Filters
                      if (showFilters)
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade900.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Search Field
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    onChanged: (text) {
                                      searchKeyword = text;
                                      _filterCars();
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search by name or year...',
                                      hintStyle: TextStyle(color: Colors.grey[400]),
                                      prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.blueGrey.shade700,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                // Price Filter
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
                                            activeColor: Colors.tealAccent,
                                            checkColor: Colors.black,
                                          ),
                                          const Text(
                                            'Price (€)',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: minPriceController,
                                              enabled: usePriceFilter,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Min',
                                                labelStyle: TextStyle(color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.blueGrey.shade700,
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              style: const TextStyle(color: Colors.white),
                                              onChanged: (value) => _filterCars(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: maxPriceController,
                                              enabled: usePriceFilter,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Max',
                                                labelStyle: TextStyle(color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.blueGrey.shade700,
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              style: const TextStyle(color: Colors.white),
                                              onChanged: (value) => _filterCars(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Mileage Filter
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
                                            activeColor: Colors.tealAccent,
                                            checkColor: Colors.black,
                                          ),
                                          const Text(
                                            'Mileage (km)',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: minMileageController,
                                              enabled: useMileageFilter,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Min',
                                                labelStyle: TextStyle(color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.blueGrey.shade700,
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              style: const TextStyle(color: Colors.white),
                                              onChanged: (value) => _filterCars(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: maxMileageController,
                                              enabled: useMileageFilter,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Max',
                                                labelStyle: TextStyle(color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.blueGrey.shade700,
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              style: const TextStyle(color: Colors.white),
                                              onChanged: (value) => _filterCars(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Year Filter
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
                                            activeColor: Colors.tealAccent,
                                            checkColor: Colors.black,
                                          ),
                                          const Text(
                                            'Year',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: minYearController,
                                              enabled: useYearFilter,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Min',
                                                labelStyle: TextStyle(color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.blueGrey.shade700,
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              style: const TextStyle(color: Colors.white),
                                              onChanged: (value) => _filterCars(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: maxYearController,
                                              enabled: useYearFilter,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Max',
                                                labelStyle: TextStyle(color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.blueGrey.shade700,
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              style: const TextStyle(color: Colors.white),
                                              onChanged: (value) => _filterCars(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Cars List
                      Expanded(
                        child: FutureBuilder<List<Car>>(
                          future: _carsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                            } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                              return Center(
                                child: Text(
                                  'No cars available: $statusMessage',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              );
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
                ),
              ),
            ],
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


              return // In PaginatedCarList's build method, replace the Card widget with this:
Card(
  elevation: 5,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ListingDetailsPage(car: car),
        ),
      );
    },
    borderRadius: BorderRadius.circular(12),
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
