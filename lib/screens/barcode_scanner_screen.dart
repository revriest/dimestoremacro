import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Barcode', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900, fontSize: 14)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              _scanned = true;
              Navigator.pop(context, raw);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                child: const Text('Point the camera at a UPC/EAN barcode to auto-fill macros.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
