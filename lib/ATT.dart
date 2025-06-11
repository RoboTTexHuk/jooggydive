import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class AttScreen extends StatefulWidget {
  const AttScreen({Key? key}) : super(key: key);

  @override
  State<AttScreen> createState() => _AttScreenState();
}

class _AttScreenState extends State<AttScreen> {
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkATT();
  }

  Future<void> _checkATT() async {
    TrackingStatus status = TrackingStatus.notDetermined;
    try {
      status = await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (e) {
      status = TrackingStatus.notSupported;
    }
    setState(() {
      _status = status.toString();
    });
    if (status == TrackingStatus.authorized ||
        status == TrackingStatus.denied ||
        status == TrackingStatus.restricted ||
        status == TrackingStatus.notSupported) {
      _goNext();
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _requestATT() async {
    setState(() {
      _loading = true;
    });
    try {
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {}
    _goNext();
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MyRootApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Allow tracking to receive personalized offers and advertisements. You can always change your choice in the settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _requestATT,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}