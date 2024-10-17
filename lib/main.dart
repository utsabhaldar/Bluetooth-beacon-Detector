import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Beacon Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BeaconScannerScreen(),
    );
  }
}

class BeaconScannerScreen extends StatefulWidget {
  const BeaconScannerScreen({super.key});

  @override
  _BeaconScannerScreenState createState() => _BeaconScannerScreenState();
}

class _BeaconScannerScreenState extends State<BeaconScannerScreen> {
  List<BluetoothDevice> devicesList = [];
  bool isScanning = false;
  Map<String, BluetoothDevice> connectedDevices = {};

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    await _requestPermissions();

    var subscription =
        FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print(state);
      if (state == BluetoothAdapterState.on) {
        _startScan();
      } else if (state == BluetoothAdapterState.off) {
        if (Platform.isAndroid) {
          _turnOnBluetooth();
        } else {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Bluetooth is Off'),
                content: const Text('Please enable Bluetooth in settings.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      subscription.cancel();
    });
  }

  Future<void> _requestPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.locationWhenInUse.request().isGranted) {
      // Permissions granted
    } else {
      openAppSettings();
    }
  }

  Future<void> _turnOnBluetooth() async {
    await FlutterBluePlus.turnOn();
    print("Bluetooth turned on");
  }

  void _startScan() async {
    setState(() {
      devicesList.clear();
      isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (ScanResult r in results) {
          if (!devicesList
              .any((device) => device.remoteId == r.device.remoteId)) {
            devicesList.add(r.device);
          }
        }
      });
    });

    // Stop scanning after the timeout
    await Future.delayed(const Duration(seconds: 5), () {
      FlutterBluePlus.stopScan();
      setState(() {
        isScanning = false;
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        connectedDevices[device.remoteId.toString()] = device;
      });
      print("Connected to ${device.platformName}");
    } catch (e) {
      print("Could not connect to ${device.platformName}: $e");
    }
  }

  Future<void> _disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      setState(() {
        connectedDevices.remove(device.remoteId.toString());
      });
      print("Disconnected from ${device.platformName}");
    } catch (e) {
      print("Could not disconnect from ${device.platformName}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Beacon Detector'),
      ),
      body: isScanning
          ? const Center(child: CircularProgressIndicator())
          : devicesList.isEmpty
              ? const Center(child: Text('No devices found'))
              : ListView.builder(
                  itemCount: devicesList.length,
                  itemBuilder: (context, index) {
                    final device = devicesList[index];
                    final isConnected = connectedDevices
                        .containsKey(device.remoteId.toString());

                    return ListTile(
                      title: Text(device.platformName.isNotEmpty
                          ? device.platformName
                          : '(unknown device)'),
                      subtitle: Text(device.remoteId.toString()),
                      trailing: ElevatedButton(
                        onPressed: () {
                          if (isConnected) {
                            _disconnectFromDevice(device);
                          } else {
                            _connectToDevice(device);
                          }
                        },
                        child: Text(isConnected ? 'Disconnect' : 'Connect'),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : _startScan,
        child: const Icon(Icons.search),
      ),
    );
  }
}
