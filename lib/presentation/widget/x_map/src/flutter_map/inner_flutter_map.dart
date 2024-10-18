import 'package:daejeon_taxi/presentation/widget/x_map/src/flutter_map/inner_flutter_map_controller.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/x_map.dart';
import 'package:daejeon_taxi/res/consts.dart';
import 'package:daejeon_taxi/utils/latlng.dart';
import 'package:daejeon_taxi/utils/nlatlng.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';

class InnerFlutterMap extends StatefulWidget {
  final XMapController controller;
  final VoidCallback? onMapReady;
  final NLatLng initialLocation;
  final int initialZoom;
  final NLocationTrackingMode defaultLocationTrackingMode;
  final LocationChangeCallback? onLocationChange;
  final VoidCallback? onCameraChange;
  final VoidCallback? onCameraIdle;

  const InnerFlutterMap({
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
  State<InnerFlutterMap> createState() => _InnerFlutterMapState();
}

class _InnerFlutterMapState extends State<InnerFlutterMap> {
  late final InnerFlutterMapController _innerMapController;

  void _onLocationChange(LatLng location) {
    final nLocation = location.toNLatLng();
    widget.onLocationChange?.call(nLocation);
    _innerMapController.onLocationChange(nLocation);
  }

  /* Flutter Map 관련 시작 */
  late final _flutterMapController = MapController();

  late final _mapOptions = MapOptions(
    initialCenter: widget.initialLocation.toLatLng(),
    initialZoom: widget.initialZoom.toDouble(),
    onMapReady: () {
      _innerMapController.flutterMapController = _flutterMapController;
      widget.controller.isMapReady = true;
    },
  );

  final _tileProvider = MyTileProvider();

  static const double _tileSize = 1024;
  static const double _zoomOffset = -((_tileSize) / 256 - 2);

  /* Flutter Map 관련 끝 */

  @override
  void initState() {
    super.initState();

    widget.controller.innerMapController =
        _innerMapController = InnerFlutterMapController();
  }

  @override
  void dispose() {
    _flutterMapController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _flutterMapController,
      options: _mapOptions,
      children: [
        TileLayer(
          // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileProvider: _tileProvider,
          tileSize: _tileSize,
          zoomOffset: _zoomOffset,
          retinaMode: true,
        ),
      ],
    );
  }
}

class MyTileProvider extends NetworkTileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final x = coordinates.x,
        y = coordinates.y,
        z = (coordinates.z + options.zoomOffset).toInt();
    final size = options.tileSize.toInt();
    final url = '$tileProviderBaseUrl/maptile?size=$size&x=$x&y=$y&z=$z';

    return NetworkImage(url);
  }
}
