import 'package:daejeon_taxi/presentation/view/map_page.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool? _loadSuccess;

  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timestamp) {
      checkPerm();
    });
  }

  void checkPerm() async {
    PermissionStatus status = await Permission.location.status;
    if (mounted) {
      setState(() {
        _status = status;
      });
    }
    if (!status.isGranted) {
      status = await Permission.location.request();
      setState(() {
        _status = status;
      });
    }
    if (mounted) {
      if (status.isGranted) {
        setState(() {
          _loadSuccess = true;
        });
      } else {
        setState(() {
          _loadSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: checkPerm,
              child: const Text('Check perm'),
            ),
            Offstage(
              offstage: _loadSuccess != null,
              child: const CircularProgressIndicator(),
            ),
            Offstage(
              offstage: _loadSuccess != true,
              child: Column(
                children: [
                  const Icon(Icons.check),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const MapPage()),
                      );
                    },
                    child: const Text('Client'),
                  ),
                ],
              ),
            ),
            Offstage(
              offstage: _loadSuccess != false,
              child: const Column(
                children: [
                  Icon(Icons.close),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
