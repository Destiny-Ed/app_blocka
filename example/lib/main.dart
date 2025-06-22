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
  final AppBlocka _appBlocka = AppBlocka();
  List<AppInfo> _apps = [];
  List<AppInfo> _allApps = []; // For Android picker
  List<String> _selectedBundleIds = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _appBlocka.initialize();
    if (await _appBlocka.checkPermission() ||
        await _appBlocka.requestPermission()) {
      if (Platform.isAndroid) {
        // Load all apps for Android picker
        await _loadAllApps();
      } else {
        await _loadApps();
      }
    }
  }

  Future<void> _loadAllApps() async {
    try {
      final apps = await _appBlocka.getAvailableApps();
      setState(() {
        _allApps = apps;
      });
    } catch (e) {
      print('Error loading all apps: $e');
    }
  }

  Future<void> _loadApps() async {
    try {
      final apps = await _appBlocka.getAvailableApps();
      setState(() {
        _apps = apps;
      });
    } catch (e) {
      print('Error loading selected apps: $e');
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (await _appBlocka.presentAppPicker(
                    bundleIds: _selectedBundleIds,
                  )) {
                    await _loadApps();
                    Navigator.pop(context);
                  }
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
              if (Platform.isAndroid) {
                _showAndroidPicker();
              } else {
                if (await _appBlocka.presentAppPicker()) {
                  await _loadApps();
                }
              }
            },
            child: const Text('Select Apps to Restrict'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _apps.length,
            itemBuilder: (context, index) {
              final app = _apps[index];
              return ListTile(
                leading:
                    app.icon != null
                        ? Image.memory(base64Decode(app.icon!))
                        : const Icon(Icons.app_blocking),
                title: Text(app.name),
                subtitle: Text(app.packageName),
                onTap: () async {
                  await _appBlocka.blockApp(app.packageName);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
