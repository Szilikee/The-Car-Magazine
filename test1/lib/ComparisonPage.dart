import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ComparisonPage extends StatefulWidget {
  final String selectedLanguage;

  const ComparisonPage({super.key, required this.selectedLanguage});

  @override
  _ComparisonPageState createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  String? selectedBrandCar1, selectedBrandCar2, selectedModelCar1, selectedModelCar2, selectedTrimCar1, selectedTrimCar2;
  int? selectedYearCar1, selectedYearCar2;
  Map<String, dynamic>? carDetailsCar1, carDetailsCar2;
  List<String> carBrands = [];
  List<String> carModelsCar1 = [], carModelsCar2 = [];
  List<String> carTrimsCar1 = [], carTrimsCar2 = [];
  List<int> carYearsCar1 = [], carYearsCar2 = [];

  // Translations (mirroring HomePage's structure)
  final Map<String, Map<String, String>> translations = {
    'en': {
      'appTitle': 'The Car Magazin',
      'comparisonPageTitle': 'Car Comparison',
      'selectCar': 'Select car',
      'selectBrand': 'Select Brand',
      'selectModel': 'Select Model for ',
      'selectTrim': 'Select Trim for ',
      'selectYear': 'Select Year for ',
      'comparisonResult': 'Comparison Result',
      'pleaseSelectAll': 'Please select all options for both cars to compare.',
      'property': 'Property',
    },
    'hu': {
      'appTitle': 'Az Autó Magazin',
      'comparisonPageTitle': 'Autó Összehasonlítás',
      'selectCar': 'Válassz autót',
      'selectBrand': 'Válassz márkát',
      'selectModel': 'Válassz modellt ',
      'selectTrim': 'Válassz felszereltséget ',
      'selectYear': 'Válassz évet ',
      'comparisonResult': 'Összehasonlítás Eredménye',
      'pleaseSelectAll': 'Kérlek, válassz ki minden opciót mindkét autóhoz az összehasonlításhoz.',
      'property': 'Tulajdonság',
    },
  };

  @override
  void initState() {
    super.initState();
    fetchCarBrands();
  }

  Future<void> fetchCarBrands() async {
    var response = await http.get(Uri.parse('https://localhost:7164/api/cars/brands'));
    if (response.statusCode == 200) {
      setState(() {
        carBrands = List<String>.from(json.decode(response.body));
      });
    } else {
      throw Exception('Failed to load car brands');
    }
  }

  Future<void> fetchCarModels(String brand, int carNumber) async {
    var response = await http.get(Uri.parse('https://localhost:7164/api/cars/models?brand=$brand'));
    if (response.statusCode == 200) {
      setState(() {
        if (carNumber == 1) {
          carModelsCar1 = List<String>.from(json.decode(response.body));
        } else {
          carModelsCar2 = List<String>.from(json.decode(response.body));
        }
      });
    } else {
      throw Exception('Failed to load car models');
    }
  }

  Future<void> fetchCarTrims(String brand, String model, int carNumber) async {
    var response = await http.get(Uri.parse('https://localhost:7164/api/cars/trims?brand=$brand&model=$model'));
    if (response.statusCode == 200) {
      setState(() {
        if (carNumber == 1) {
          carTrimsCar1 = List<String>.from(json.decode(response.body));
        } else {
          carTrimsCar2 = List<String>.from(json.decode(response.body));
        }
      });
    } else {
      throw Exception('Failed to load car trims');
    }
  }

  Future<void> fetchCarYears(String brand, String model, String trim, int carNumber) async {
    var response = await http.get(Uri.parse('https://localhost:7164/api/cars/years?brand=$brand&model=$model&trim=$trim'));
    if (response.statusCode == 200) {
      setState(() {
        if (carNumber == 1) {
          carYearsCar1 = List<int>.from(json.decode(response.body));
        } else {
          carYearsCar2 = List<int>.from(json.decode(response.body));
        }
      });
    } else {
      throw Exception('Failed to load car years');
    }
  }

  Future<void> fetchCarDetails(String brand, String model, String trim, int year, int carNumber) async {
    var url = 'https://localhost:7164/api/cars/details?brand=$brand&model=$model&trim=$trim&year=$year';
    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        data['brand'] = brand;
        setState(() {
          if (carNumber == 1) {
            carDetailsCar1 = data as Map<String, dynamic>;
          } else {
            carDetailsCar2 = data as Map<String, dynamic>;
          }
        });
      } else {
        throw Exception('Failed to load car details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in fetchCarDetails: $e');
      rethrow;
    }
  }

  String getBrandImagePath(String brand) {
    if (brand.isEmpty) return 'logos/default.png';
    String cleanBrand = brand.toLowerCase().replaceAll(' ', '');
    return 'logos/$cleanBrand.png';
  }

  Widget buildComparisonTable() {
    bool isDataComplete = [
      selectedBrandCar1,
      selectedBrandCar2,
      selectedModelCar1,
      selectedModelCar2,
      selectedTrimCar1,
      selectedTrimCar2,
      selectedYearCar1,
      selectedYearCar2,
      carDetailsCar1,
      carDetailsCar2
    ].every((element) => element != null);

    if (!isDataComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            translations[widget.selectedLanguage]!['pleaseSelectAll']!,
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCarColumn(selectedModelCar1!, carDetailsCar1!, Colors.blue),
            _buildCarColumn(selectedModelCar2!, carDetailsCar2!, Colors.green),
          ],
        ),
        const SizedBox(height: 16),
        _buildComparisonCard(),
      ],
    );
  }

  Widget _buildCarColumn(String model, Map<String, dynamic> details, Color color) {
    String brand = (details['brand'] ?? '').toString().toLowerCase();
    String imagePath = getBrandImagePath(brand);
    
    return Expanded(
      child: Column(
        children: [
          Text(
            model,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          Image.asset(
            imagePath,
            height: 150,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultImage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultImage() {
    return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
  }

  Widget _buildComparisonCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columnSpacing: 20,
          columns: [
            _buildDataColumn(translations[widget.selectedLanguage]!['property']!, null),
            _buildDataColumn(selectedModelCar1!, Colors.blue),
            _buildDataColumn(selectedModelCar2!, Colors.green),
          ],
          rows: [
            _buildDataRow('Brand', selectedBrandCar1, selectedBrandCar2),
            _buildDataRow('Model', selectedModelCar1, selectedModelCar2),
            _buildDataRow('Trim', selectedTrimCar1, selectedTrimCar2),
            _buildDataRow('Year', selectedYearCar1.toString(), selectedYearCar2.toString()),
            _buildDataRow('Price', '£${carDetailsCar1!['price']?.toString() ?? 'N/A'}', '£${carDetailsCar2!['price']?.toString() ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label, [Color? color]) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
      ),
    );
  }

  DataRow _buildDataRow(String property, String? value1, String? value2) {
    return DataRow(
      cells: [
        DataCell(Text(property, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(value1 ?? 'N/A', style: const TextStyle(color: Colors.blue))),
        DataCell(Text(value2 ?? 'N/A', style: const TextStyle(color: Colors.green))),
      ],
    );
  }

  Widget buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(hint, style: const TextStyle(color: Colors.grey)),
            isExpanded: true,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString(), style: const TextStyle(fontSize: 16)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          translations[widget.selectedLanguage]!['comparisonPageTitle']!,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translations[widget.selectedLanguage]!['selectCar']!,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            buildDropdown<String>(
                              value: selectedBrandCar1,
                              hint: translations[widget.selectedLanguage]!['selectBrand']!,
                              items: carBrands,
                              onChanged: (value) {
                                setState(() {
                                  selectedBrandCar1 = value;
                                  selectedModelCar1 = null;
                                  selectedTrimCar1 = null;
                                  selectedYearCar1 = null;
                                  carModelsCar1.clear();
                                  carTrimsCar1.clear();
                                  carYearsCar1.clear();
                                  carDetailsCar1 = null;
                                  fetchCarModels(value!, 1);
                                });
                              },
                            ),
                            if (selectedBrandCar1 != null)
                              buildDropdown<String>(
                                value: selectedModelCar1,
                                hint: translations[widget.selectedLanguage]!['selectModel']! + selectedBrandCar1!,
                                items: carModelsCar1,
                                onChanged: (value) {
                                  setState(() {
                                    selectedModelCar1 = value;
                                    selectedTrimCar1 = null;
                                    selectedYearCar1 = null;
                                    carTrimsCar1.clear();
                                    carYearsCar1.clear();
                                    carDetailsCar1 = null;
                                    fetchCarTrims(selectedBrandCar1!, value!, 1);
                                  });
                                },
                              ),
                            if (selectedModelCar1 != null)
                              buildDropdown<String>(
                                value: selectedTrimCar1,
                                hint: translations[widget.selectedLanguage]!['selectTrim']! + selectedBrandCar1!,
                                items: carTrimsCar1,
                                onChanged: (value) async {
                                  setState(() {
                                    selectedTrimCar1 = value;
                                    selectedYearCar1 = null;
                                    carYearsCar1.clear();
                                    carDetailsCar1 = null;
                                  });
                                  await fetchCarYears(selectedBrandCar1!, selectedModelCar1!, value!, 1);
                                  setState(() {});
                                },
                              ),
                            if (selectedTrimCar1 != null && carYearsCar1.isNotEmpty)
                              buildDropdown<int>(
                                value: selectedYearCar1,
                                hint: translations[widget.selectedLanguage]!['selectYear']! + selectedBrandCar1!,
                                items: carYearsCar1,
                                onChanged: (value) async {
                                  setState(() {
                                    selectedYearCar1 = value;
                                    carDetailsCar1 = null;
                                  });
                                  await fetchCarDetails(selectedBrandCar1!, selectedModelCar1!, selectedTrimCar1!, value!, 1);
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translations[widget.selectedLanguage]!['selectCar']!,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            buildDropdown<String>(
                              value: selectedBrandCar2,
                              hint: translations[widget.selectedLanguage]!['selectBrand']!,
                              items: carBrands,
                              onChanged: (value) {
                                setState(() {
                                  selectedBrandCar2 = value;
                                  selectedModelCar2 = null;
                                  selectedTrimCar2 = null;
                                  selectedYearCar2 = null;
                                  carModelsCar2.clear();
                                  carTrimsCar2.clear();
                                  carYearsCar2.clear();
                                  carDetailsCar2 = null;
                                  fetchCarModels(value!, 2);
                                });
                              },
                            ),
                            if (selectedBrandCar2 != null)
                              buildDropdown<String>(
                                value: selectedModelCar2,
                                hint: translations[widget.selectedLanguage]!['selectModel']! + selectedBrandCar2!,
                                items: carModelsCar2,
                                onChanged: (value) {
                                  setState(() {
                                    selectedModelCar2 = value;
                                    selectedTrimCar2 = null;
                                    selectedYearCar2 = null;
                                    carTrimsCar2.clear();
                                    carYearsCar2.clear();
                                    carDetailsCar2 = null;
                                    fetchCarTrims(selectedBrandCar2!, value!, 2);
                                  });
                                },
                              ),
                            if (selectedModelCar2 != null)
                              buildDropdown<String>(
                                value: selectedTrimCar2,
                                hint: translations[widget.selectedLanguage]!['selectTrim']! + selectedBrandCar2!,
                                items: carTrimsCar2,
                                onChanged: (value) async {
                                  setState(() {
                                    selectedTrimCar2 = value;
                                    selectedYearCar2 = null;
                                    carYearsCar2.clear();
                                    carDetailsCar2 = null;
                                  });
                                  await fetchCarYears(selectedBrandCar2!, selectedModelCar2!, value!, 2);
                                  setState(() {});
                                },
                              ),
                            if (selectedTrimCar2 != null && carYearsCar2.isNotEmpty)
                              buildDropdown<int>(
                                value: selectedYearCar2,
                                hint: translations[widget.selectedLanguage]!['selectYear']! + selectedBrandCar2!,
                                items: carYearsCar2,
                                onChanged: (value) async {
                                  setState(() {
                                    selectedYearCar2 = value;
                                    carDetailsCar2 = null;
                                  });
                                  await fetchCarDetails(selectedBrandCar2!, selectedModelCar2!, selectedTrimCar2!, value!, 2);
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      translations[widget.selectedLanguage]!['comparisonResult']!,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    buildComparisonTable(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}