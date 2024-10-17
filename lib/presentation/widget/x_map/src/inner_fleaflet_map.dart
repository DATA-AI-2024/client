import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class InnerFleafletMap extends StatefulWidget {
  const InnerFleafletMap({super.key});

  @override
  State<InnerFleafletMap> createState() => _InnerFleafletMapState();
}

class _InnerFleafletMapState extends State<InnerFleafletMap> {
  late final _mapController = MapController();
  late final _mapOptions = const MapOptions(
    initialCenter: LatLng(37.554024, 127.141967),
  );

  final _tileProvider = MyTileProvider();

  static const double _tileSize = 1024;
  static const double _zoomOffset = -((_tileSize) / 256 - 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
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
      ),
    );
  }
}

class MyTileProvider extends NetworkTileProvider {
  static const _baseUrl = 'http://intra.kykint.com:5981';

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final x = coordinates.x,
        y = coordinates.y,
        z = (coordinates.z + options.zoomOffset).toInt();
    final size = options.tileSize.toInt();
    final url = '$_baseUrl/maptile?size=$size&x=$x&y=$y&z=$z';

    return NetworkImage(url);
  }
}
