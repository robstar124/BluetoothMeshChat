import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Mesh Chat',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AdvertiserScreen(), // 👈 important
    );
  }
}

class AdvertiserScreen extends StatefulWidget {
  const AdvertiserScreen({super.key});

  @override
  State<AdvertiserScreen> createState() => _AdvertiserScreenState();
}

class _AdvertiserScreenState extends State<AdvertiserScreen> {
  static const _channel = MethodChannel('ble_advertiser');
  String _status = "Idle";

  Future<void> _startAdvertising() async {
    setState(() => _status = "Starting...");

    try {
      final result = await _channel.invokeMethod('startAdvertising');
      setState(() => _status = "✅ $result");
    } on PlatformException catch (e) {
      setState(() => _status = "❌ Failed: ${e.message}");
    } catch (e) {
      setState(() => _status = "❌ Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Advertiser")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth),
                label: const Text("Start Advertising"),
                onPressed: _startAdvertising,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
