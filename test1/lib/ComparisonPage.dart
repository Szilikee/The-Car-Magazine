import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});

  @override
  _ComparisonPageState createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  List<String> carModelsCar1 = [];
  List<String> carModelsCar2 = [];
  dynamic dataCar1;
  dynamic dataCar2;
  bool isLoading = false;
  TextEditingController car1Controller = TextEditingController();
  TextEditingController car2Controller = TextEditingController();

  @override
  void dispose() {
    car1Controller.dispose();
    car2Controller.dispose();
    super.dispose();
  }

  Future<void> fetchCarModels(String carBrand, {required bool isCar1}) async {
    setState(() => isLoading = true);
    String url = 'https://localhost:7164/api/cars/models?brand=$carBrand';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          if (isCar1) {
            carModelsCar1 = jsonResponse.cast<String>();
          } else {
            carModelsCar2 = jsonResponse.cast<String>();
          }
        });
      } else {
        throw Exception('Failed to load car models');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

Future<void> fetchData(String carModel, {required bool isCar1}) async {
  setState(() => isLoading = true);

  // Csak a modell részét küldjük el a kéréshez
  List<String> parts = carModel.split(' ');
  String modelOnly = parts.length > 1 ? parts.sublist(1).join(' ') : carModel;
  String url = 'https://localhost:7164/api/cars/details?model=$modelOnly';

  print('Küldött URL: $url'); // Logoljuk a küldött URL-t

  try {
    final response = await http.get(Uri.parse(url));
    print('API válasz kód: ${response.statusCode}'); // API válaszkód logolása

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      print('API válasz: $jsonResponse'); // A válasz logolása

      if (mounted) {
        setState(() {
          if (isCar1) {
            dataCar1 = jsonResponse;
          } else {
            dataCar2 = jsonResponse;
          }
        });
      }
    } else {
      throw Exception('Nem sikerült betölteni az adatokat - Status Code: ${response.statusCode}');
    }
  } catch (e) {
    print('Hiba: $e'); // Hiba logolása
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}



  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Car Comparison"),
      centerTitle: true,
      elevation: 0,
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: "Car 1",
                  controller: car1Controller,
                  onChanged: (newValue) {
                    fetchCarModels(newValue, isCar1: true);
                  },
                  isCar1: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Car 2",
                  controller: car2Controller,
                  onChanged: (newValue) {
                    fetchCarModels(newValue, isCar1: false);
                  },
                  isCar1: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading && (dataCar1 == null || dataCar2 == null)
                ? const Center(child: CircularProgressIndicator())
                : (dataCar1 == null || dataCar2 == null)
                    ? const Center(child: Text("Select two cars to compare"))
                    : _buildComparisonTable(),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTextField({
  required String label,
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  required bool isCar1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (context, constraints) {
          return Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              await fetchCarModels(textEditingValue.text, isCar1: isCar1);
              return (isCar1 ? carModelsCar1 : carModelsCar2)
                  .where((model) => model.toLowerCase().startsWith(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              controller.text = selection;
              fetchData(selection, isCar1: isCar1);
            },
            optionsMaxHeight: 200,
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              controller.addListener(() {
                textEditingController.text = controller.text;
              });
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: "Enter Car Model",
                  border: const OutlineInputBorder(),
                  suffixIcon: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                      maxHeight: 200,
                    ),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final String option = options.elementAt(index);
                            bool isHovered = false; // Local hover state
                            return MouseRegion(
                              onEnter: (_) => setState(() => isHovered = true),
                              onExit: (_) => setState(() => isHovered = false),
                              child: GestureDetector(
                                onTap: () => onSelected(option),
                                child: Container(
                                  color: isHovered ? Colors.grey[200] : Colors.transparent,
                                  child: ListTile(
                                    title: Text(option),
                                    hoverColor: Colors.grey[300],
                                    dense: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

Widget _buildComparisonTable() {
  if (dataCar1 == null || dataCar2 == null) {
    return const Center(child: Text("Select two cars to compare"));
  }

  // Lekérdezzük a modelleket
  String car1Name = dataCar1?['model'] ?? 'No data';
  String car2Name = dataCar2?['model'] ?? 'No data';

  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            "Comparing: $car1Name vs $car2Name",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(3),
              },
              children: [
                _buildTableRow("Attribute", car1Name, car2Name, isHeader: true),
                _buildTableRow("Price (€)", dataCar1?['price']?.toString() ?? 'No data', dataCar2?['price']?.toString() ?? 'No data'),
                _buildTableRow("Year", dataCar1?['year']?.toString() ?? 'No data', dataCar2?['year']?.toString() ?? 'No data'),
                _buildTableRow("Fuel Type", dataCar1?['fuelType'] ?? 'No data', dataCar2?['fuelType'] ?? 'No data'),
                _buildTableRow("Max Power", dataCar1?['maxPower'] ?? 'No data', dataCar2?['maxPower'] ?? 'No data'),
                _buildTableRow("Max Torque", dataCar1?['maxTorque'] ?? 'No data', dataCar2?['maxTorque'] ?? 'No data'),
                _buildTableRow("Drivetrain", dataCar1?['drivetrain'] ?? 'No data', dataCar2?['drivetrain'] ?? 'No data'),
                _buildTableRow("Engine", dataCar1?['engine'] ?? 'No data', dataCar2?['engine'] ?? 'No data'),
                _buildTableRow("Transmission", dataCar1?['transmission'] ?? 'No data', dataCar2?['transmission'] ?? 'No data'),
                _buildTableRow("Length", dataCar1?['length']?.toString() ?? 'No data', dataCar2?['length']?.toString() ?? 'No data'),
                _buildTableRow("Width", dataCar1?['width']?.toString() ?? 'No data', dataCar2?['width']?.toString() ?? 'No data'),
                _buildTableRow("Height", dataCar1?['height']?.toString() ?? 'No data', dataCar2?['height']?.toString() ?? 'No data'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


TableRow _buildTableRow(String attribute, String value1, String value2, {bool isHeader = false}) {
  return TableRow(
    decoration: isHeader ? BoxDecoration(color: Colors.blueAccent.withOpacity(0.1)) : null,
    children: [
      _buildTableCell(attribute, isHeader),
      _buildTableCell(value1, isHeader),
      _buildTableCell(value2, isHeader),
    ],
  );
}

Widget _buildTableCell(String text, bool isHeader) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        color: isHeader ? Colors.blueAccent : Colors.white,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
}