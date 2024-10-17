import 'dart:math';

import 'package:daejeon_taxi/presentation/widget/x_map/src/inner_map_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:meta/meta.dart';

class XMapController extends ChangeNotifier {
  final id = Random().nextInt(1000);

  /* Map properties */
  bool shouldMockLocation = false;

  bool getShouldMockLocation() {
    return shouldMockLocation;
  }

  void setShouldMockLocation(bool value) {
    shouldMockLocation = value;
    if (value) {
      innerMapController
        ?..setMockLocationMarker()
        ..setLocationTrackingMode(NLocationTrackingMode.none);
    } else {
      innerMapController
        ?..removeMockLocationMarker()
        ..setLocationTrackingMode(NLocationTrackingMode.face);
    }
    notifyListeners();
  }

  bool isMapReady = false;

  NLatLng? getCurrentLocation() {
    return innerMapController?.getCurrentLocation();
  }

  Future<NLocationTrackingMode?> getLocationTrackingMode() async {
    return await innerMapController?.getLocationTrackingMode();
  }

  Future<void> setLocationTrackingMode(NLocationTrackingMode value) async {
    return await innerMapController?.setLocationTrackingMode(value);
  }

  void moveTo(NLatLng location) {
    innerMapController?.moveTo(location);
  }

  void addOverlay(NAddableOverlay overlay) {
    innerMapController?.addOverlay(overlay);
  }

  void removeOverlay(NAddableOverlay overlay) {
    innerMapController?.removeOverlay(overlay);
  }

  /* Internal */

  @internal
  InnerMapController? innerMapController;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = false;
    innerMapController?.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
}
