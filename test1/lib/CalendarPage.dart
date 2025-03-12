import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart' as xml;

class Race {
  final String name;
  final DateTime raceDate;
  final String time;
  final String circuitName;
  final String raceUrl;
  final String circuitUrl;

  Race({
    required this.name,
    required this.raceDate,
    required this.time,
    required this.circuitName,
    required this.raceUrl,
    required this.circuitUrl,
  });

  // Static method to convert string to DateTime
  static DateTime parseDate(String dateStr) {
    return DateFormat("yyyy-MM-dd").parse(dateStr);
  }
}

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  List<Race> races = [];
  String selectedYear = '2024'; // Default year
  List<String> years = [];

@override
void initState() {
  super.initState();
  _generateYearList();
  if (!years.contains(selectedYear)) {
    selectedYear = years.isNotEmpty ? years.first : '2024'; // Fallback to default year
  }
  fetchRaceSchedule();
}

void _generateYearList() {
  int currentYear = DateTime.now().year;
  int startYear = 1950;
  years = List.generate(currentYear - startYear + 1, (index) => (startYear + index).toString());
}



Future<void> fetchRaceSchedule() async {
  final url = 'http://ergast.com/api/f1/$selectedYear/races'; // URL to fetch races for the selected year

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);

      final raceList = document.findAllElements('Race').map((raceElement) {
        final raceName = raceElement.findElements('RaceName').isNotEmpty
            ? raceElement.findElements('RaceName').single.text
            : 'No Name';
        final raceDate = raceElement.findElements('Date').isNotEmpty
            ? Race.parseDate(raceElement.findElements('Date').single.text)
            : DateTime.utc(2000, 1, 1); // Default to some far past date
        final raceTime = raceElement.findElements('Time').isNotEmpty
            ? raceElement.findElements('Time').single.text
            : 'TBD';
        final circuitName = raceElement.findElements('Circuit').isNotEmpty &&
                raceElement.findElements('Circuit').single.findElements('CircuitName').isNotEmpty
            ? raceElement.findElements('Circuit').single.findElements('CircuitName').single.text
            : 'Unknown Circuit';
        final raceUrl = raceElement.findElements('Race').isNotEmpty
            ? raceElement.findElements('Race').single.getAttribute('url') ?? 'https://example.com'
            : 'https://example.com';
        final circuitUrl = raceElement.findElements('Circuit').isNotEmpty
            ? raceElement.findElements('Circuit').single.getAttribute('url') ?? 'https://example.com'
            : 'https://example.com';

        return Race(
          name: raceName,
          raceDate: raceDate,
          time: raceTime,
          circuitName: circuitName,
          raceUrl: raceUrl,
          circuitUrl: circuitUrl,
        );
      }).toList();

      setState(() {
        races = raceList;
      });
    } else {
      throw Exception('Failed to load race schedule');
    }
  } catch (e) {
    print('Error fetching data: $e');
    // Handle the error gracefully, e.g., show an alert or a fallback message
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Race Schedule'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown to select the year
            DropdownButton<String>(
              value: selectedYear,
              onChanged: (String? newValue) {
                setState(() {
                  selectedYear = newValue!;
                  _generateYearList(); // Update the year range
                });
                fetchRaceSchedule(); // Fetch the race schedule for the selected year
              },
              items: years
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            // Display races in a ListView
            Expanded(
              child: ListView.builder(
                itemCount: races.length,
                itemBuilder: (context, index) {
                  final race = races[index];
                  return ListTile(
                    title: Text(race.name),
                    subtitle: Text('${DateFormat.yMMMd().format(race.raceDate)} at ${race.time}'),
                    onTap: () async {
                      final circuitUrl = Uri.parse(race.circuitUrl); // Use circuit URL
                      if (await canLaunch(circuitUrl.toString())) {
                        await launch(circuitUrl.toString()); // Launch the circuit URL
                      } else {
                        throw 'Could not launch ${race.circuitUrl}';
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
