import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'Translations.dart';
class ComparisonPage extends StatefulWidget {
  final String selectedLanguage;

  const ComparisonPage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  _ComparisonPageState createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> with SingleTickerProviderStateMixin {
  String? selectedBrandCar1, selectedBrandCar2, selectedModelCar1, selectedModelCar2, selectedTrimCar1, selectedTrimCar2;
  int? selectedYearCar1, selectedYearCar2;
  Map<String, dynamic> carDetailsCar1 = {};
  Map<String, dynamic> carDetailsCar2 = {};
  List<String> carBrands = [];
  List<String> carModelsCar1 = [], carModelsCar2 = [];
  List<String> carTrimsCar1 = [], carTrimsCar2 = [];
  List<int> carYearsCar1 = [], carYearsCar2 = [];
  bool isLoading = false;
  late TabController _tabController;

  // Hardcoded background image path
  final String imagePath = 'assets/pictures/backgroundimage.png';

 
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCarBrands();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch methods (unchanged)
  Future<void> fetchCarBrands() async {
    var response = await http.get(Uri.parse('https://localhost:7164/api/cars/brands'));
    if (response.statusCode == 200) {
      setState(() {
        carBrands = List<String>.from(json.decode(response.body));
      });
    } else {
      print('Failed to load car brands: ${response.statusCode} - ${response.body}');
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
      print('Failed to load car models: ${response.statusCode} - ${response.body}');
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
      print('Failed to load car trims: ${response.statusCode} - ${response.body}');
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
      print('Failed to load car years: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> fetchCarDetails(String brand, String model, String trim, int year, int carNumber) async {
    var url = 'https://localhost:7164/api/cars/details?brand=$brand&model=$model&trim=$trim&year=$year';
    try {
      setState(() {
        isLoading = true;
      });
      var response = await http.get(Uri.parse(url));
      print('fetchCarDetails URL: $url');
      print('fetchCarDetails Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        var data = json.decode(response.body) as Map<String, dynamic>? ?? {};
        print('fetchCarDetails Data: $data');
        data['brand'] = brand;
        data['genmodel_ID'] = data['genmodel_ID']?.toString() ?? 'N/A';
        data['price'] = data['price'] ?? 0;
        data['gas_emission'] = data['gas_emission'] ?? 0;
        data['fuel_type'] = data['fuel_type']?.toString() ?? 'N/A';
        data['engine_size'] = data['engine_size'] ?? 0;
        setState(() {
          if (carNumber == 1) {
            carDetailsCar1 = data;
          } else {
            carDetailsCar2 = data;
          }
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          if (carNumber == 1) {
            carDetailsCar1 = {};
          } else {
            carDetailsCar2 = {};
          }
        });
        print('Failed to load car details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        if (carNumber == 1) {
          carDetailsCar1 = {};
        } else {
          carDetailsCar2 = {};
        }
      });
      print('Error in fetchCarDetails: $e');
    }
  }

  String getBrandImagePath(String brand) {
    if (brand.isEmpty) return 'logos/default.png';
    String cleanBrand = brand.toLowerCase().replaceAll(' ', '');
    return 'logos/$cleanBrand.png';
  }

  Widget buildComparisonTable() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
        ),
      );
    }

    bool isSelectionComplete = [
      selectedBrandCar1,
      selectedBrandCar2,
      selectedModelCar1,
      selectedModelCar2,
      selectedTrimCar1,
      selectedTrimCar2,
      selectedYearCar1,
      selectedYearCar2,
    ].every((element) => element != null);

    if (!isSelectionComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            translations[widget.selectedLanguage]!['pleaseSelectAll']!,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[300],
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCarColumn(selectedModelCar1 ?? 'N/A', carDetailsCar1, Colors.blue),
            const SizedBox(width: 20),
            _buildCarColumn(selectedModelCar2 ?? 'N/A', carDetailsCar2, Colors.green),
          ],
        ),
        const SizedBox(height: 20),
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.tealAccent,
          indicatorColor: Colors.tealAccent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: [
            Tab(text: translations[widget.selectedLanguage]!['tableView']),
            Tab(text: translations[widget.selectedLanguage]!['chartView']),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: TabBarView(
            controller: _tabController,
            children: [
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildComparisonCard(),
                ),
              ),
              SingleChildScrollView(child: _buildComparisonCharts()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarColumn(String model, Map<String, dynamic> details, Color color) {
    String brand = (details['brand'] ?? '').toString().toLowerCase();
    String imagePath = getBrandImagePath(brand);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade800.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              model,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color == Colors.blue ? Colors.blueAccent : Colors.greenAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              child: Image.asset(
                imagePath,
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultImage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Icon(
      Icons.image_not_supported,
      size: 100,
      color: Colors.grey[400],
    );
  }

  Widget _buildComparisonCard() {
    final model1 = selectedModelCar1 ?? 'Car 1';
    final model2 = selectedModelCar2 ?? 'Car 2';
    final language = translations.containsKey(widget.selectedLanguage) ? widget.selectedLanguage : 'en';
    final translationMap = translations[language]!;

    return Card(
      elevation: 6,
      color: Colors.blueGrey.shade900.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DataTable(
          columnSpacing: 40,
          headingRowHeight: 56,
          dataRowHeight: 48,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
          dataTextStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey[200],
          ),
          columns: [
            DataColumn(
              label: Text(
                translationMap['property'] ?? 'Property',
                textAlign: TextAlign.left,
              ),
            ),
            DataColumn(
              label: Text(
                model1,
                style: const TextStyle(color: Colors.blueAccent),
                textAlign: TextAlign.center,
              ),
            ),
            DataColumn(
              label: Text(
                model2,
                style: const TextStyle(color: Colors.greenAccent),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          rows: [
            DataRow(cells: [
              DataCell(Text(translationMap['brand'] ?? 'Brand')),
              DataCell(Text(selectedBrandCar1 ?? 'N/A', textAlign: TextAlign.center)),
              DataCell(Text(selectedBrandCar2 ?? 'N/A', textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['model'] ?? 'Model')),
              DataCell(Text(model1, textAlign: TextAlign.center)),
              DataCell(Text(model2, textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['trim'] ?? 'Trim')),
              DataCell(Text(selectedTrimCar1 ?? 'N/A', textAlign: TextAlign.center)),
              DataCell(Text(selectedTrimCar2 ?? 'N/A', textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['year'] ?? 'Year')),
              DataCell(Text(selectedYearCar1?.toString() ?? 'N/A', textAlign: TextAlign.center)),
              DataCell(Text(selectedYearCar2?.toString() ?? 'N/A', textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['price'] ?? 'Price')),
              DataCell(Text('£${carDetailsCar1['price']?.toString() ?? 'N/A'}', textAlign: TextAlign.center)),
              DataCell(Text('£${carDetailsCar2['price']?.toString() ?? 'N/A'}', textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['gasEmission'] ?? 'Gas Emission')),
              DataCell(Text(carDetailsCar1['gas_emission']?.toString() ?? 'N/A', textAlign: TextAlign.center)),
              DataCell(Text(carDetailsCar2['gas_emission']?.toString() ?? 'N/A', textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['fuelType'] ?? 'Fuel Type')),
              DataCell(Text(carDetailsCar1['fuel_type']?.toString() ?? 'N/A', textAlign: TextAlign.center)),
              DataCell(Text(carDetailsCar2['fuel_type']?.toString() ?? 'N/A', textAlign: TextAlign.center)),
            ]),
            DataRow(cells: [
              DataCell(Text(translationMap['engineSize'] ?? 'Engine Size')),
              DataCell(Text(carDetailsCar1['engine_size']?.toString() ?? 'N/A', textAlign: TextAlign.center)),
              DataCell(Text(carDetailsCar2['engine_size']?.toString() ?? 'N/A', textAlign: TextAlign.center)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCharts() {
    final language = translations.containsKey(widget.selectedLanguage) ? widget.selectedLanguage : 'en';
    return Column(
      children: [
        _buildBarChart(
          title: translations[language]!['priceChart']!,
          value1: (carDetailsCar1['price'] ?? 0).toDouble(),
          value2: (carDetailsCar2['price'] ?? 0).toDouble(),
          maxY: ((carDetailsCar1['price'] ?? 0).toDouble() > (carDetailsCar2['price'] ?? 0).toDouble()
                  ? (carDetailsCar1['price'] ?? 0).toDouble()
                  : (carDetailsCar2['price'] ?? 0).toDouble()) *
              1.2,
          label1: selectedModelCar1 ?? 'Car 1',
          label2: selectedModelCar2 ?? 'Car 2',
          color1: Colors.blueAccent,
          color2: Colors.greenAccent,
        ),
        const SizedBox(height: 24),
        _buildBarChart(
          title: translations[language]!['emissionChart']!,
          value1: (carDetailsCar1['gas_emission'] ?? 0).toDouble(),
          value2: (carDetailsCar2['gas_emission'] ?? 0).toDouble(),
          maxY: ((carDetailsCar1['gas_emission'] ?? 0).toDouble() > (carDetailsCar2['gas_emission'] ?? 0).toDouble()
                  ? (carDetailsCar1['gas_emission'] ?? 0).toDouble()
                  : (carDetailsCar2['gas_emission'] ?? 0).toDouble()) *
              1.2,
          label1: selectedModelCar1 ?? 'Car 1',
          label2: selectedModelCar2 ?? 'Car 2',
          color1: Colors.blueAccent,
          color2: Colors.greenAccent,
        ),
        const SizedBox(height: 24),
        _buildBarChart(
          title: translations[language]!['engineSizeChart']!,
          value1: (carDetailsCar1['engine_size'] ?? 0).toDouble(),
          value2: (carDetailsCar2['engine_size'] ?? 0).toDouble(),
          maxY: ((carDetailsCar1['engine_size'] ?? 0).toDouble() > (carDetailsCar2['engine_size'] ?? 0).toDouble()
                  ? (carDetailsCar1['engine_size'] ?? 0).toDouble()
                  : (carDetailsCar2['engine_size'] ?? 0).toDouble()) *
              1.2,
          label1: selectedModelCar1 ?? 'Car 1',
          label2: selectedModelCar2 ?? 'Car 2',
          color1: Colors.blueAccent,
          color2: Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _buildBarChart({
    required String title,
    required double value1,
    required double value2,
    required double maxY,
    required String label1,
    required String label2,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBorder: BorderSide(
                      color: Colors.tealAccent.withOpacity(0.5),
                      width: 1,
                    ),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tooltipMargin: 8,
                    getTooltipColor: (group) => Colors.blueGrey.shade700.withOpacity(0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final value = rod.toY;
                      return BarTooltipItem(
                        value.toStringAsFixed(0),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: value1,
                        gradient: LinearGradient(
                          colors: [color1, color1.withOpacity(0.7)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: value2,
                        gradient: LinearGradient(
                          colors: [color2, color2.withOpacity(0.7)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 80,
                      getTitlesWidget: (value, meta) {
                        String text;
                        switch (value.toInt()) {
                          case 0:
                            text = label1;
                            break;
                          case 1:
                            text = label2;
                            break;
                          default:
                            text = '';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.tealAccent.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.tealAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(width: 14, height: 14, color: color1),
                  const SizedBox(width: 6),
                  Text(label1, style: const TextStyle(fontSize: 14, color: Colors.white)),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Container(width: 14, height: 14, color: color2),
                  const SizedBox(width: 6),
                  Text(label2, style: const TextStyle(fontSize: 14, color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade700,
              Colors.blueGrey.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(
              hint,
              style: TextStyle(color: Colors.grey[300], fontSize: 16),
            ),
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: Colors.blueGrey.shade800,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
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
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.4),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) {
                // Fallback gradient if image fails to load
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
              // Custom AppBar
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
                        translations[widget.selectedLanguage]!['comparisonPageTitle']!,
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
                child: SingleChildScrollView(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Card(
                                elevation: 6,
                                color: Colors.blueGrey.shade900.withOpacity(0.9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        translations[widget.selectedLanguage]!['selectCar']!,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
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
                                            carDetailsCar1 = {};
                                            if (value != null) {
                                              fetchCarModels(value, 1);
                                            }
                                          });
                                        },
                                      ),
                                      if (selectedBrandCar1 != null)
                                        buildDropdown<String>(
                                          value: selectedModelCar1,
                                          hint: translations[widget.selectedLanguage]!['selectModel']! +
                                              (selectedBrandCar1 ?? ''),
                                          items: carModelsCar1,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedModelCar1 = value;
                                              selectedTrimCar1 = null;
                                              selectedYearCar1 = null;
                                              carTrimsCar1.clear();
                                              carYearsCar1.clear();
                                              carDetailsCar1 = {};
                                              if (value != null) {
                                                fetchCarTrims(selectedBrandCar1!, value, 1);
                                              }
                                            });
                                          },
                                        ),
                                      if (selectedModelCar1 != null)
                                        buildDropdown<String>(
                                          value: selectedTrimCar1,
                                          hint: translations[widget.selectedLanguage]!['selectTrim']! +
                                              (selectedBrandCar1 ?? ''),
                                          items: carTrimsCar1,
                                          onChanged: (value) async {
                                            setState(() {
                                              selectedTrimCar1 = value;
                                              selectedYearCar1 = null;
                                              carYearsCar1.clear();
                                              carDetailsCar1 = {};
                                            });
                                            if (value != null) {
                                              await fetchCarYears(selectedBrandCar1!, selectedModelCar1!, value, 1);
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      if (selectedTrimCar1 != null && carYearsCar1.isNotEmpty)
                                        buildDropdown<int>(
                                          value: selectedYearCar1,
                                          hint: translations[widget.selectedLanguage]!['selectYear']! +
                                              (selectedBrandCar1 ?? ''),
                                          items: carYearsCar1,
                                          onChanged: (value) async {
                                            setState(() {
                                              selectedYearCar1 = value;
                                              carDetailsCar1 = {};
                                            });
                                            if (value != null) {
                                              await fetchCarDetails(
                                                  selectedBrandCar1!, selectedModelCar1!, selectedTrimCar1!, value, 1);
                                            }
                                            setState(() {});
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Card(
                                elevation: 6,
                                color: Colors.blueGrey.shade900.withOpacity(0.9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        translations[widget.selectedLanguage]!['selectCar']!,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.greenAccent,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
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
                                            carDetailsCar2 = {};
                                            if (value != null) {
                                              fetchCarModels(value, 2);
                                            }
                                          });
                                        },
                                      ),
                                      if (selectedBrandCar2 != null)
                                        buildDropdown<String>(
                                          value: selectedModelCar2,
                                          hint: translations[widget.selectedLanguage]!['selectModel']! +
                                              (selectedBrandCar2 ?? ''),
                                          items: carModelsCar2,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedModelCar2 = value;
                                              selectedTrimCar2 = null;
                                              selectedYearCar2 = null;
                                              carTrimsCar2.clear();
                                              carYearsCar2.clear();
                                              carDetailsCar2 = {};
                                              if (value != null) {
                                                fetchCarTrims(selectedBrandCar2!, value, 2);
                                              }
                                            });
                                          },
                                        ),
                                      if (selectedModelCar2 != null)
                                        buildDropdown<String>(
                                          value: selectedTrimCar2,
                                          hint: translations[widget.selectedLanguage]!['selectTrim']! +
                                              (selectedBrandCar2 ?? ''),
                                          items: carTrimsCar2,
                                          onChanged: (value) async {
                                            setState(() {
                                              selectedTrimCar2 = value;
                                              selectedYearCar2 = null;
                                              carYearsCar2.clear();
                                              carDetailsCar2 = {};
                                            });
                                            if (value != null) {
                                              await fetchCarYears(selectedBrandCar2!, selectedModelCar2!, value, 2);
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      if (selectedTrimCar2 != null && carYearsCar2.isNotEmpty)
                                        buildDropdown<int>(
                                          value: selectedYearCar2,
                                          hint: translations[widget.selectedLanguage]!['selectYear']! +
                                              (selectedBrandCar2 ?? ''),
                                          items: carYearsCar2,
                                          onChanged: (value) async {
                                            setState(() {
                                              selectedYearCar2 = value;
                                              carDetailsCar2 = {};
                                            });
                                            if (value != null) {
                                              await fetchCarDetails(
                                                  selectedBrandCar2!, selectedModelCar2!, selectedTrimCar2!, value, 2);
                                            }
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
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              buildComparisonTable(),
                            ],
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
}