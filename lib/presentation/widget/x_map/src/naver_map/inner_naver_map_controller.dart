import 'package:daejeon_taxi/presentation/widget/x_map/src/inner_map_controller.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:meta/meta.dart';

class InnerNaverMapController implements InnerMapController {
  NaverMapController? naverMapController;

  bool isMapReady = false;

  NLatLng? lastLocation;

  NMarker? _mockLocationMarker;

  static const _mockLocationMarkerId = 'MOCK_LOCATION_MARKER';

  InnerNaverMapController({
    this.naverMapController,
    this.isMapReady = false,
  });

  @override
  NLatLng? getCurrentLocation() {
    return lastLocation;
  }

  @override
  void moveTo(NLatLng location) {
    naverMapController?.updateCamera(
      NCameraUpdate.fromCameraPosition(
          NCameraPosition(target: location, zoom: 13)),
    );
  }

  @override
  Future<NLocationTrackingMode?> getLocationTrackingMode() async {
    return await naverMapController?.getLocationTrackingMode();
  }

  @override
  Future<void> setLocationTrackingMode(NLocationTrackingMode mode) async {
    return naverMapController?.setLocationTrackingMode(mode);
  }

  @override
  void setMockLocationMarker() {
    if (naverMapController == null || lastLocation == null) return;

    if (_mockLocationMarker == null) {
      _mockLocationMarker = NMarker(
        id: _mockLocationMarkerId,
        position: lastLocation!,
      );
      naverMapController?.addOverlay(_mockLocationMarker!);
    }
  }

  @override
  void removeMockLocationMarker() {
    if (_mockLocationMarker != null) {
      naverMapController?.deleteOverlay(_mockLocationMarker!.info);
      _mockLocationMarker = null;
    }
  }

  @override
  void addOverlay(NAddableOverlay overlay) {
    naverMapController?.addOverlay(overlay);
  }

  @override
  void removeOverlay(NAddableOverlay overlay) {
    naverMapController?.deleteOverlay(overlay.info);
  }

  /* Internal */

  @internal
  void onLocationChange(NLatLng location) {
    lastLocation = location;
    _mockLocationMarker?.setPosition(location);
  }

  @override
  void dispose() {
    naverMapController?.dispose();
    naverMapController = null;
  }
}
