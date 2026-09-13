import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

void main() {
  runApp(const HRRideApp());
}

class HRRideApp extends StatelessWidget {
  const HRRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HR RIDE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR RIDE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to HR Ride',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your trusted ride service',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingPage(),
                    ),
                  );
                },
                child: const Text(
                  'BOOK NOW',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final pickupController = TextEditingController();
  final dropController = TextEditingController();

  // এখানে আপনার Google Maps API Key বসাবেন
  final String googleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  @override
  void dispose() {
    pickupController.dispose();
    dropController.dispose();
    super.dispose();
  }

  InputDecoration locationDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.location_on),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Your Ride',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            GooglePlaceAutoCompleteTextField(
              textEditingController: pickupController,
              googleAPIKey: googleApiKey,
              inputDecoration: locationDecoration(
                'Enter pickup location',
              ),
              debounceTime: 600,
              countries: const ['in'],
              isLatLngRequired: true,
              getPlaceDetailWithLatLng: (Prediction prediction) {
                debugPrint(
                  'Pickup: ${prediction.description}',
                );
                debugPrint(
                  'Latitude: ${prediction.lat}',
                );
                debugPrint(
                  'Longitude: ${prediction.lng}',
                );
              },
              itemClick: (Prediction prediction) {
                pickupController.text =
                    prediction.description ?? '';
                pickupController.selection =
                    TextSelection.fromPosition(
                  TextPosition(
                    offset: pickupController.text.length,
                  ),
                );
              },
              itemBuilder: (
                BuildContext context,
                int index,
                Prediction prediction,
              ) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(
                    prediction.description ?? '',
                  ),
                );
              },
              seperatedBuilder: const Divider(),
            ),

            const SizedBox(height: 25),

            const Text(
              'Drop Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            GooglePlaceAutoCompleteTextField(
              textEditingController: dropController,
              googleAPIKey: googleApiKey,
              inputDecoration: locationDecoration(
                'Enter drop location',
              ),
              debounceTime: 600,
              countries: const ['in'],
              isLatLngRequired: true,
              getPlaceDetailWithLatLng: (Prediction prediction) {
                debugPrint(
                  'Drop: ${prediction.description}',
                );
                debugPrint(
                  'Latitude: ${prediction.lat}',
                );
                debugPrint(
                  'Longitude: ${prediction.lng}',
                );
              },
              itemClick: (Prediction prediction) {
                dropController.text =
                    prediction.description ?? '';
                dropController.selection =
                    TextSelection.fromPosition(
                  TextPosition(
                    offset: dropController.text.length,
                  ),
                );
              },
              itemBuilder: (
                BuildContext context,
                int index,
                Prediction prediction,
              ) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(
                    prediction.description ?? '',
                  ),
                );
              },
              seperatedBuilder: const Divider(),
            ),

            const SizedBox(height: 25),

            Card(
              elevation: 3,
              child: const ListTile(
                leading: Icon(
                  Icons.directions_car,
                  size: 40,
                ),
                title: Text(
                  'Maruti Ertiga',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('HR RIDE'),
                trailing: Text(
                  '22 km/l',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (pickupController.text.trim().isEmpty ||
                      dropController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select pickup and drop location',
                        ),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Booking request submitted!',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'CONFIRM BOOKING',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
