import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertsSection extends StatelessWidget {
  const AlertsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final alertsRef = FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: alertsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "⚠️ Active Flood Alerts",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...alerts.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                color: _getColorBySeverity(data['severity']),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.white),
                  title: Text(
                    data['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    data['message'] ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Text(
                    data['severity'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  static Color _getColorBySeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }
}
