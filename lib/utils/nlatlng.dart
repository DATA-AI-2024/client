import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';

extension NLatLngExtension on NLatLng {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}
