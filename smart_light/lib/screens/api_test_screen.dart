import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final TextEditingController _deviceIdController = TextEditingController(
    text: 'smartlight_5966e0',
  );
  final TextEditingController _servo1Controller = TextEditingController(
    text: '90',
  );
  final TextEditingController _servo2Controller = TextEditingController(
    text: '90',
  );
  final TextEditingController _brightnessController = TextEditingController(
    text: '0.5',
  );
  final TextEditingController _colorRController = TextEditingController(
    text: '255',
  );
  final TextEditingController _colorGController = TextEditingController(
    text: '255',
  );
  final TextEditingController _colorBController = TextEditingController(
    text: '255',
  );
  String _response = '';

  Future<void> _testGetDevices() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.20.10.13:3000/devices'),
      );
      setState(() {
        _response =
            'GET /devices\nStatus: ${response.statusCode}\nBody: ${response.body}';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    }
  }

  Future<void> _testUpdateServo() async {
    try {
      final body = jsonEncode({
        'servo1Angle': int.parse(_servo1Controller.text),
        'servo2Angle': int.parse(_servo2Controller.text),
      });
      final response = await http.post(
        Uri.parse(
          'http://192.168.0.105:3000/devices/${_deviceIdController.text}/servo',
        ),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      setState(() {
        _response =
            'POST /devices/${_deviceIdController.text}/servo\nStatus: ${response.statusCode}\nBody: ${response.body}';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    }
  }

  Future<void> _testUpdateLed() async {
    try {
      final body = jsonEncode({
        'brightness': double.parse(_brightnessController.text),
        'colorR': int.parse(_colorRController.text),
        'colorG': int.parse(_colorGController.text),
        'colorB': int.parse(_colorBController.text),
      });
      final response = await http.post(
        Uri.parse(
          'http://192.168.0.105:3000/devices/${_deviceIdController.text}/led',
        ),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      setState(() {
        _response =
            'POST /devices/${_deviceIdController.text}/led\nStatus: ${response.statusCode}\nBody: ${response.body}';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(controller: _deviceIdController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testGetDevices,
              child: const Text('GET /devices'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Servo Control:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _servo1Controller,
                    decoration: const InputDecoration(
                      labelText: 'Servo 1 Angle',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _servo2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Servo 2 Angle',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _testUpdateServo,
              child: const Text('POST /devices/:id/servo'),
            ),
            const SizedBox(height: 20),
            const Text(
              'LED Control:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _brightnessController,
              decoration: const InputDecoration(labelText: 'Brightness'),
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _colorRController,
                    decoration: const InputDecoration(labelText: 'Color R'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _colorGController,
                    decoration: const InputDecoration(labelText: 'Color G'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _colorBController,
                    decoration: const InputDecoration(labelText: 'Color B'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _testUpdateLed,
              child: const Text('POST /devices/:id/led'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Response:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: SingleChildScrollView(child: Text(_response)),
            ),
          ],
        ),
      ),
    );
  }
}
