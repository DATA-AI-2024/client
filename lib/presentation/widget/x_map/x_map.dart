import 'dart:io';

import 'package:daejeon_taxi/presentation/widget/x_map/src/inner_fleaflet_map.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/src/naver_map/inner_naver_map.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/src/x_map_controller.dart';
import 'package:daejeon_taxi/res/consts.dart';
import 'package:daejeon_taxi/utils/throttler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

export './src/x_map_controller.dart';

typedef LocationChangeCallback = void Function(NLatLng location);

class XMap extends StatefulWidget {
  final XMapController? controller;
  final VoidCallback? onMapReady;

  /// 사용자의 실제 위치가 변경됐거나, 컨트롤러의 [shouldMockLocation]이 [true]일 경우
  /// 카메라 위치가 변경됐을 경우 해당 위치에 대한 정보를 반환함.
  final LocationChangeCallback? onLocationChange;
  final NLatLng initialLocation;
  final int initialZoom;
  final NLocationTrackingMode defaultLocationTrackingMode;
  final VoidCallback? onCameraChange;
  final VoidCallback? onCameraIdle;

  const XMap({
    super.key,
    this.controller,
    this.onMapReady,
    this.onLocationChange,
    this.initialLocation = daejeonStation,
    this.initialZoom = 13,
    this.defaultLocationTrackingMode = NLocationTrackingMode.none,
    this.onCameraChange,
    this.onCameraIdle,
  });

  @override
  State<XMap> createState() => _XMapState();
}

class _XMapState extends State<XMap> {
  /// 테스트용으로, 지도를 움직이면 그곳을 현재 위치로 지도에 표시하고 서버에 보고함
  // bool get _shouldMockLocation => context.watch<XMapController>().shouldMockLocation;

  late final XMapController _controller;

  final _stateThrottler = Throttler(throttleGapInMillis: 100);

  void _onLocationChange(NLatLng location) {
    widget.onLocationChange?.call(location);
  }

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? XMapController();
  }

  @override
  void dispose() {
    super.dispose();

    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => _controller,
      child: Stack(
        children: [
          Platform.isAndroid || Platform.isIOS
              ? InnerNaverMap(
                  controller: _controller,
                  onMapReady: widget.onMapReady,
                  initialLocation: widget.initialLocation,
                  initialZoom: widget.initialZoom,
                  defaultLocationTrackingMode:
                      widget.defaultLocationTrackingMode,
                  onLocationChange: _onLocationChange,
                  onCameraChange: widget.onCameraChange,
                  onCameraIdle: widget.onCameraIdle,
                )
              : const InnerFleafletMap(/*_controller*/),
        ],
      ),
    );
  }
}
