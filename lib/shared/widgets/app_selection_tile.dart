import 'dart:convert';
import 'package:flutter/material.dart';

class AppSelectionTile extends StatelessWidget {
  final String name;
  final String packageName;
  final String iconBase64;
  final bool isSelected;
  final ValueChanged<String> onToggle;

  const AppSelectionTile({
    super.key,
    required this.name,
    required this.packageName,
    required this.iconBase64,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: iconBase64.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(iconBase64),
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.android, color: Colors.black45),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: Checkbox(
        value: isSelected,
        activeColor: Colors.black,
        onChanged: (val) => onToggle(packageName),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onTap: () => onToggle(packageName),
    );
  }
}