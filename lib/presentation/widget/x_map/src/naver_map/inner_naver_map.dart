import 'package:daejeon_taxi/presentation/widget/x_map/src/naver_map/inner_naver_map_controller.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/x_map.dart';
import 'package:daejeon_taxi/res/consts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class InnerNaverMap extends StatefulWidget {
  final XMapController controller;
  final VoidCallback? onMapReady;
  final NLatLng initialLocation;
  final int initialZoom;
  final NLocationTrackingMode defaultLocationTrackingMode;
  final LocationChangeCallback? onLocationChange;
  final VoidCallback? onCameraChange;
  final VoidCallback? onCameraIdle;

  const InnerNaverMap({
    required this.controller,
    this.onMapReady,
    this.initialLocation = daejeonStation,
    this.initialZoom = 13,
    this.defaultLocationTrackingMode = NLocationTrackingMode.none,
    this.onLocationChange,
    this.onCameraChange,
    this.onCameraIdle,
    super.key,
  });

  @override
  State<InnerNaverMap> createState() => _InnerNaverMapState();
}

class _InnerNaverMapState extends State<InnerNaverMap> {
  NaverMapController? _naverMapController;

  late final InnerNaverMapController _innerMapController;

  void _onLocationChange(NLatLng location) {
    widget.onLocationChange?.call(location);
    _innerMapController.onLocationChange(location);
  }

  @override
  void initState() {
    super.initState();

    _innerMapController = InnerNaverMapController();
    widget.controller.innerMapController = _innerMapController;
  }

  @override
  void dispose() {
    _naverMapController?.dispose();
    _naverMapController = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: widget.initialLocation,
          zoom: 13,
        ),
      ),
      onMapReady: (controller) {
        _naverMapController = controller;
        _innerMapController.naverMapController = controller;
        widget.controller.isMapReady = true;
        controller.setLocationTrackingMode(widget.defaultLocationTrackingMode);
        final overlay = controller.getLocationOverlay();
        overlay.setIsVisible(true);
        widget.onMapReady?.call();
        _onLocationChange(widget.initialLocation);
      },
      onCameraChange: (reason, animated) {
        if (_naverMapController == null) {
          return;
        }

        // gps 위치 변동 시, 혹은 mock location 모드에서 지도 움직였을 시 위치 변동 콜백
        final shouldMockLocation = widget.controller.getShouldMockLocation();
        final shouldTrackLocation = reason == NCameraUpdateReason.location ||
            (reason == NCameraUpdateReason.gesture && shouldMockLocation);
        if (shouldTrackLocation) {
          _onLocationChange(_naverMapController!.nowCameraPosition.target);
        }

        // TODO: 코드 수정
        /*
        // 타겟 위치 범위 내에 도착 시
        debugPrint('running setState: ${_nearTarget}');
        _stateThrottler.run(() => setState(() {}));
        _reportLocation(reason);
        */
      },
      onCameraIdle: () {
        widget.onCameraIdle?.call();
      },
    );
  }
}
