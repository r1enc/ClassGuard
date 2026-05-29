import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ClassroomCard extends StatelessWidget {
  final String subject;
  final String lecturer;
  final String room;
  final String roomCode;
  final String securityPIN;

  const ClassroomCard({
    super.key,
    required this.subject,
    required this.lecturer,
    required this.room,
    required this.roomCode,
    required this.securityPIN,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Text(lecturer, style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Text(room, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          const Text(
            'SECURITY CREDENTIALS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Classroom Code', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    roomCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: roomCode));
                  Fluttertoast.showToast(msg: "Code Copied!");
                },
                icon: const Icon(Icons.copy, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency PIN', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    securityPIN,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.vpn_key_outlined, color: Colors.white70),
            ],
          ),
        ],
      ),
    );
  }
}