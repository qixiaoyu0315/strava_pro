import 'package:flutter/material.dart';

class RouteDetailPage extends StatelessWidget {
  final String idStr;

  const RouteDetailPage({Key? key, required this.idStr}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Details'),
      ),
      body: Center(
        child: Text(
          'Route ID: $idStr',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
} 