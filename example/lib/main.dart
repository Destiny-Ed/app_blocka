import 'package:app_blocka/app_blocka.dart';
import 'package:app_blocka/app_usage_info_model.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App Blocker')),
        body: const AppListScreen(),
      ),
    );
  }
}

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  _AppListScreenState createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  List<AppInfo> _allApps = [];
  List<String> _selectedBundleIds = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    print('Initializing AppBlocka');

    final hasPermission = await AppBlocka.checkPermission();
    print('Permission status: $hasPermission');
    if (!hasPermission) {
      final granted = await AppBlocka.requestPermission();
      print('Permission granted: $granted');
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enable Family Controls in Settings > Screen Time',
            ),
          ),
        );
        return;
      }
    }
    print('Initialization complete, loading apps');
    await _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      print('Loading apps via getAvailableApps');
      final apps = await AppBlocka.getAvailableApps();
      print(
        'Loaded apps: ${apps.length} apps - ${apps.map((a) => a.packageName).toList()}',
      );
      setState(() {
        _allApps = [];
        _allApps = apps;
        _selectedBundleIds = apps.map((a) => a.packageName).toList();
      });
    } catch (e) {
      print('Error loading apps: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load apps: $e')));
    }
  }

  void _showAndroidPicker() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Apps to Restrict'),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                itemCount: _allApps.length,
                itemBuilder: (context, index) {
                  final app = _allApps[index];
                  return CheckboxListTile(
                    title: Text(app.name),
                    subtitle: Text(app.packageName),
                    value: _selectedBundleIds.contains(app.packageName),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedBundleIds.add(app.packageName);
                        } else {
                          _selectedBundleIds.remove(app.packageName);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  print('Android picker: Cancelled');
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  print(
                    'Android picker: Selected bundle IDs: $_selectedBundleIds',
                  );
                  setState(() {
                    _allApps =
                        _allApps
                            .where(
                              (app) =>
                                  _selectedBundleIds.contains(app.packageName),
                            )
                            .toList();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              print('Button pressed: Fetching apps');
              if (Platform.isAndroid) {
                await _loadApps();
                print('Showing Android picker');
                _showAndroidPicker();
              } else {
                await _loadApps();
              }
            },
            child: const Text('Select Apps to Restrict'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _allApps.length,
            itemBuilder: (context, index) {
              final app = _allApps[index];
              return ListTile(
                leading:
                    app.icon != null
                        ? Image.memory(base64Decode(app.icon!))
                        : const Icon(Icons.app_blocking),
                title: Text(app.name),
                subtitle: Text(app.packageName),
                onTap: () async {
                  print('Blocking app: ${app.packageName}');
                  await AppBlocka.blockApp(app.packageName);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
