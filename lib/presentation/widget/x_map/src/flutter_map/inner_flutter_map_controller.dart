import 'package:daejeon_taxi/presentation/widget/x_map/src/inner_map_controller.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:meta/meta.dart';

class InnerFlutterMapController implements InnerMapController {
  MapController? flutterMapController;

  bool isMapReady = false;

  NLatLng? lastLocation;

  NMarker? _mockLocationMarker;

  static const _mockLocationMarkerId = 'MOCK_LOCATION_MARKER';

  InnerFlutterMapController({
    this.flutterMapController,
    this.isMapReady = false,
  });

  @override
  NLatLng? getCurrentLocation() {
    return lastLocation;
  }

  @override
  void moveTo(NLatLng location) {
    flutterMapController?.updateCamera(
      NCameraUpdate.fromCameraPosition(
          NCameraPosition(target: location, zoom: 13)),
    );
  }

  @override
  Future<NLocationTrackingMode?> getLocationTrackingMode() async {
    return await flutterMapController?.getLocationTrackingMode();
  }

  @override
  Future<void> setLocationTrackingMode(NLocationTrackingMode mode) async {
    return flutterMapController?.setLocationTrackingMode(mode);
  }

  @override
  void setMockLocationMarker() {
    if (flutterMapController == null || lastLocation == null) return;

    if (_mockLocationMarker == null) {
      _mockLocationMarker = NMarker(
        id: _mockLocationMarkerId,
        position: lastLocation!,
      );
      flutterMapController?.addOverlay(_mockLocationMarker!);
    }
  }

  @override
  void removeMockLocationMarker() {
    if (_mockLocationMarker != null) {
      flutterMapController?.deleteOverlay(_mockLocationMarker!.info);
      _mockLocationMarker = null;
    }
  }

  @override
  void addOverlay(NAddableOverlay overlay) {
    flutterMapController?.addOverlay(overlay);
  }

  @override
  void removeOverlay(NAddableOverlay overlay) {
    flutterMapController?.deleteOverlay(overlay.info);
  }

  /* Internal */

  @internal
  void onLocationChange(NLatLng location) {
    lastLocation = location;
    _mockLocationMarker?.setPosition(location);
  }

  @override
  void dispose() {
    flutterMapController?.dispose();
    flutterMapController = null;
  }
}
