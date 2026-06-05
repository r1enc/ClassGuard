import 'dart:convert';
import 'dart:ui';

import 'package:classguard/core/services/firestore_service.dart';

// UI KIT IMPORTS
import 'package:classguard/shared/widgets/app_selection_tile.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SelectAppsScreen extends StatefulWidget {
  // Holds the initially selected apps passed from the previous screen
  final List<String> initialSelectedApps;
  const SelectAppsScreen({super.key, required this.initialSelectedApps});

  @override
  State<SelectAppsScreen> createState() => _SelectAppsScreenState();
}

class _SelectAppsScreenState extends State<SelectAppsScreen> {
  // Platform channel to communicate with native code for retrieving device apps
  static const platformAppInfo = MethodChannel('com.classguard/app_info');
  final FirestoreService _firestoreService = FirestoreService();

  // Variables to store fetched application data
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _masterApps = [];

  // Loading state indicators for asynchronous data fetching
  bool _isLoadingInstalled = true;
  bool _isLoadingMaster = true;
  bool _showAll = false;

  // Stores the current list of selected application packages
  List<String> _selectedPackages = [];

  @override
  void initState() {
    super.initState();
    // Initialize the selection list with the provided initial data
    _selectedPackages = List.from(widget.initialSelectedApps);
    _fetchMasterApps();
    _fetchInstalledApps();
  }

  // STATE MANAGEMENT: Retrieve remote master list of apps from Firebase
  Future<void> _fetchMasterApps() async {
    try {
      final masterApps = await _firestoreService.fetchMasterApps();
      setState(() {
        _masterApps = masterApps;
        _isLoadingMaster = false;
      });
    } catch (e) {
      // Handle potential errors and update loading state
      setState(() => _isLoadingMaster = false);
    }
  }

  // CORE LOGIC: Invoke native channel to retrieve list of apps installed on user's device
  Future<void> _fetchInstalledApps() async {
    try {
      final List<dynamic> apps = await platformAppInfo.invokeMethod('getInstalledApps');
      setState(() {
        // Map dynamic data to a structured Map format for UI consumption
        _installedApps = apps.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingInstalled = false;
      });
    } catch (e) {
      // Ensure loading indicator is removed even if the fetch fails
      setState(() => _isLoadingInstalled = false);
    }
  }

  // STATE MANAGEMENT: Update UI selection state dynamically
  void _toggleSelection(String packageName) {
    setState(() {
      // Add or remove the package name based on its current presence in the list
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _saveSelection() {
    // Convert to Set to prevent duplicate packages, then back to List
    List<String> finalBlockedApps = _selectedPackages.toSet().toList();
    // Return the selected data to the previous screen
    Navigator.pop(context, finalBlockedApps);
  }

  @override
  Widget build(BuildContext context) {
    // Wait for both master and installed apps to finish loading
    bool isLoading = _isLoadingInstalled || _isLoadingMaster;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Select Apps", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMasterListFolder(),
                  const Divider(color: Colors.black12, thickness: 1, height: 40),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text("Most Frequently Used", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  const SizedBox(height: 10),

                  // Display a limited initial set of installed apps to optimize UI rendering
                  ..._installedApps.take(9).map((app) => AppSelectionTile(
                    name: app['name'],
                    packageName: app['package'],
                    iconBase64: app['icon']?.toString() ?? "",
                    isSelected: _selectedPackages.contains(app['package']),
                    onToggle: _toggleSelection,
                  )).toList(),

                  // Display the expand button if not all apps are shown yet
                  if (!_showAll && _installedApps.length > 9)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showAll = true),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                          label: const Text("View All Apps", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            side: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ),

                  // Render the rest of the applications if the user expands the list
                  if (_showAll) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text("All Apps", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                    ..._installedApps.skip(9).map((app) => AppSelectionTile(
                      name: app['name'],
                      packageName: app['package'],
                      iconBase64: app['icon']?.toString() ?? "",
                      isSelected: _selectedPackages.contains(app['package']),
                      onToggle: _toggleSelection,
                    )).toList(),
                  ],
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        onPressed: _saveSelection,
        label: Text("Save (${_selectedPackages.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }

  // Widget to display the entry point for the curated master list of distracting apps
  Widget _buildMasterListFolder() {
    return GestureDetector(
      onTap: _openMasterFolderDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.folder_special, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Master List Apps", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  SizedBox(height: 2),
                  Text("Contains popular distracting apps", style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  // Displays a blurred backdrop dialog showing apps fetched from Firestore
  void _openMasterFolderDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        // Use StatefulBuilder to allow local state updates within the dialog instance
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Master List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _masterApps.isEmpty
                          ? const Padding(padding: EdgeInsets.all(20), child: Text("No data available in Firebase.", style: TextStyle(color: Colors.black54)))
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 16),
                              itemCount: _masterApps.length,
                              itemBuilder: (context, index) {
                                var app = _masterApps[index];
                                // Determine current selection state for the grid item
                                bool isSelected = _selectedPackages.contains(app['package']);

                                // Load network image if available, fallback to default icon
                                Widget iconWidget = app['iconUrl'].toString().isNotEmpty
                                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(app['iconUrl'], fit: BoxFit.cover))
                                    : const Icon(Icons.apps, color: Colors.black54, size: 28);

                                return GestureDetector(
                                  onTap: () {
                                    // Update dialog state and parent state when an item is toggled
                                    setStateDialog(() => _toggleSelection(app['package']));
                                    setState(() {});
                                  },
                                  child: Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Container(
                                            height: 60, width: 60,
                                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 1.5)),
                                            child: Center(child: iconWidget),
                                          ),
                                          // Display a checkmark badge if the app is selected
                                          if (isSelected) Container(decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.check, color: Colors.white, size: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(app['name'], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}