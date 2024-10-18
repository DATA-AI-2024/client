import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';

const _distance = Distance();

extension LatLngExtension on LatLng {
  double distanceTo(LatLng other) {
    if (this == other) return 0;
    return _distance.distance(this, other);
  }

  NLatLng toNLatLng() {
    return NLatLng(latitude, longitude);
  }
}
