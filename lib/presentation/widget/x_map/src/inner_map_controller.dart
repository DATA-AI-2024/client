import 'package:flutter_naver_map/flutter_naver_map.dart';

abstract interface class InnerMapController {
  NLatLng? getCurrentLocation();

  void moveTo(NLatLng location);

  Future<NLocationTrackingMode?> getLocationTrackingMode();

  Future<void> setLocationTrackingMode(NLocationTrackingMode mode);

  void setMockLocationMarker();

  void removeMockLocationMarker();

  void addOverlay(NAddableOverlay overlay);

  void removeOverlay(NAddableOverlay overlay);

  void dispose();
}
