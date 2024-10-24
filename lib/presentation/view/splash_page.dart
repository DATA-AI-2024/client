import 'package:daejeon_taxi/domain/environment/app_state_provider.dart';
import 'package:daejeon_taxi/presentation/view/map_page.dart';
import 'package:daejeon_taxi/res/consts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomTooltip extends StatelessWidget {
  final Widget child;
  final double arrowWidth;
  final double arrowHeight;

  const CustomTooltip({
    super.key,
    required this.child,
    this.arrowWidth = 20,
    this.arrowHeight = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.red, child: _buildTooltipBubble());
  }

  Widget _buildTooltipBubble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        ),
        SizedBox(
          height: arrowHeight * 2,
          child: CustomPaint(
            painter: ArrowPainter(
              width: arrowWidth,
              height: arrowHeight,
            ),
          ),
        ),
      ],
    );
  }
}

class ArrowPainter extends CustomPainter {
  final double width;
  final double height;

  ArrowPainter({required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    var path = Path()
      ..moveTo(10, 0)
      ..arcToPoint(Offset(0, 10), radius: Radius.circular(1))
      ..lineTo(0, 10)
      ..arcToPoint(Offset(20, 10), radius: Radius.circular(1))
      ..lineTo(20, 10)
      ..arcToPoint(Offset(10, 0), radius: Radius.circular(1));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool? _loadSuccess;

  PermissionStatus? _status;

  late final TextEditingController _urlController;

  SharedPreferences? prefs;

  void _setSocketUrl() {
    ref.read(appStateProvider.notifier).setSocketUrl(_urlController.text);
  }

  @override
  void initState() {
    super.initState();

    _urlController =
        TextEditingController(text: ref.read(appStateProvider).socketUrl)
          ..addListener(_setSocketUrl);

    WidgetsBinding.instance.addPostFrameCallback((timestamp) async {
      checkPerm();

      prefs = await SharedPreferences.getInstance();
      ref.listenManual(appStateProvider, (previous, next) {
        if (previous?.socketUrl != next.socketUrl &&
            next.socketUrl != _urlController.text) {
          _urlController.text = next.socketUrl;
        }
      });
    });
  }

  @override
  void dispose() {
    _urlController.removeListener(_setSocketUrl);
    _urlController.dispose();

    super.dispose();
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _urlController.text = WS_CLIENT;
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
