import 'dart:async';
import 'dart:convert';

import 'package:daejeon_taxi/domain/environment/app_state_provider.dart';
import 'package:daejeon_taxi/presentation/component/labeled_checkbox.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/x_map.dart';
import 'package:daejeon_taxi/res/client_event.dart';
import 'package:daejeon_taxi/res/consts.dart';
import 'package:daejeon_taxi/res/taxi_state.dart';
import 'package:daejeon_taxi/utils/extension/latlng.dart';
import 'package:daejeon_taxi/utils/throttler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart';

enum MapMode {
  client,
  dashboard,
}

class MapPage extends ConsumerStatefulWidget {
  final MapMode mode;

  const MapPage(this.mode, {super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  // Start of map stuff
  late final XMapController _controller;

  bool isMapReady = false;

  final _reportThrottler = Throttler(throttleGapInMillis: 500);

  /// 서버에 위치를 실시간 보고
  bool _shouldReportLocation = true;

  NMarker? _mockMarker;

  static const _markerMockId = 'mock';

  /// 서버에서 배차를 제안한 타겟, 거절 시 배차 풀에 재등록
  LatLng? _suggestedTarget;

  static const _baechaTargetOverlayId = 'target';

  NAddableOverlay? _baechaTargetOverlay;

  /// in meters
  static const double _targetRadiusInMeters = 100;

  LatLng? _targetLocation;

  /// 현재 위치
  LatLng? _currentLocation;

  /// 타겟 범위 내에 도착하여 픽업 가능 여부
  bool? get _nearTarget => (_currentLocation == null || _targetLocation == null)
      ? null
      : _currentLocation!.distanceTo(_targetLocation!) <= _targetRadiusInMeters;

  // End of map stuff

  // Start of socket stuff
  late final Socket _socket;

  /// 소켓 연결 여부
  bool _connected = false;

  // End of socket stuff

  // TODO: FIX
  /*
  void _updateCurrentLocationMock(NCameraUpdateReason reason) {
    if (reason == NCameraUpdateReason.gesture) {
      // if (_mockMarker!=null) {
      //   _controller?.deleteOverlay(_mockMarker);
      // }
      if (_mockMarker == null) {
        _mockMarker = NMarker(
          id: _markerMockId,
          position: _controller!.nowCameraPosition.target,
        );
        _controller?.addOverlay(_mockMarker!);
      }
      _mockMarker?.setPosition(_controller!.nowCameraPosition.target);
      // _controller?.addOverlay(NMarker(
      //   id: MARKER_MOCK_ID,
      //   position: _controller!.nowCameraPosition.target,
      // ));
    }
  }
  */

  void _reportLocation([NLatLng? location]) {
    _reportThrottler.run(() {
      location ??= _controller.getCurrentLocation();
      if (location == null) {
        return;
      }

      final locationJson = jsonEncode({
        'lat': location!.latitude,
        'lng': location!.longitude,
      });
      _socket.emit(CLIENT_EVENT_UPDATE_LOCATION, locationJson);
    });
  }

  /// 택시 대기 중, 운행 중 상태 보고
  void _reportState(TaxiState state) {
    _socket.emit('state', state.name);
  }

  void _onTargetSuggested(double lat, double lng) {
    setState(() {
      // _suggestedTarget = NLatLng(lat, lng);
    });
  }

  void _rejectTarget() {
    assert(_suggestedTarget != null);

    _socket.emit('reject');
    setState(() {
      _suggestedTarget = null;
    });
  }

  /* 지도 관련 시작 */
  Timer? _returnTimer;

  void _cancelReturnToCurrentLocation() {
    _returnTimer?.cancel();
    _returnTimer = null;
  }

  void _reserveReturnToCurrentLocation() {
    _returnTimer?.cancel();
    _returnTimer = Timer(const Duration(seconds: 2), () async {
      if (!_controller.shouldMockLocation) {
        _controller.setLocationTrackingMode(NLocationTrackingMode.face);
      }

      _returnTimer = null;
    });
  }

  /* 지도 관련 끝 */

  @override
  void initState() {
    super.initState();

    _controller = XMapController();

    final socketOption = OptionBuilder().setTransports(['websocket']).build();
    if (widget.mode == MapMode.client) {
      _socket = io(WS_CLIENT, socketOption);
    } else {
      _socket = io(WS_DASHBOARD, socketOption);
    }

    _socket.onConnect((data) {
      _reportLocation();
      setState(() {
        if (mounted) {
          _connected = true;
        }
      });
    });

    _socket
      ..onDisconnect((data) {
        if (mounted) {
          _connected = false;
        }
      })
      ..on('ping', (data) {
        debugPrint('ping $data');
      })
      ..on('pong', (data) {
        debugPrint('pong $data');
      })
      ..on('baecha', (data) {
        if (data == null) return;

        debugPrint('received baecha $data');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('배차가 완료되었습니다.'),
          action: SnackBarAction(
            label: '확인',
            onPressed: () {},
          ),
        ));
        NLatLng position = NLatLng(data['lat'], data['lng']);
        // _targetLocation = position;
        if (_baechaTargetOverlay != null) {
          _controller.removeOverlay(_baechaTargetOverlay!);
        }
        _baechaTargetOverlay = NCircleOverlay(
          id: _baechaTargetOverlayId,
          center: position,
          radius: _targetRadiusInMeters,
          color: Colors.purpleAccent.withOpacity(0.3),
        );
        Timer.periodic(
          Duration(seconds: 1),
          (timer) {
            position =
                NLatLng(position.latitude + 0.01, position.longitude + 0.01);
            if (_baechaTargetOverlay is NMarker) {
              (_baechaTargetOverlay as NMarker).setPosition(position);
            } else if (_baechaTargetOverlay is NCircleOverlay) {
              (_baechaTargetOverlay as NCircleOverlay).setCenter(position);
            }
          },
        );
        _controller.addOverlay(_baechaTargetOverlay!);
        // if (_baechaTargetOverlay != null) {
        //   if (_baechaTargetOverlay is NMarker) {
        //     (_baechaTargetOverlay as NMarker).setPosition(position);
        //   } else if (_baechaTargetOverlay is NCircleOverlay) {
        //     (_baechaTargetOverlay as NCircleOverlay).setCenter(position);
        //   } else {
        //     // TODO: Consider other types?
        //   }
        // } else {
        //   _baechaTargetOverlay = NCircleOverlay(
        //     id: _targetMarkerId,
        //     center: position,
        //     radius: _targetRadiusInMeters,
        //     color: Colors.purpleAccent.withOpacity(0.3),
        //   );
        //   _controller?.addOverlay(_baechaTargetOverlay!);
        // }
      })
      ..on('hello', (data) {
        debugPrint('hello');
      });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('App'),
      ),
      body: Stack(
        children: [
          XMap(
            controller: _controller,
            onMapReady: () {
              setState(() {
                isMapReady = true;
              });
            },
            defaultLocationTrackingMode: NLocationTrackingMode.face,
            onLocationChange: (location) {
              if (_shouldReportLocation) {
                _reportLocation(location);
              }
            },
            onCameraChange: () {
              _cancelReturnToCurrentLocation();
            },
            onCameraIdle: () {
              _reserveReturnToCurrentLocation();
            },
          ),
          if (isMapReady)
            Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledCheckbox(
                    label: 'Mock location',
                    value: _controller.getShouldMockLocation(),
                    onChanged: (value) => setState(() {
                      _controller.setShouldMockLocation(value);
                    }),
                  ),
                  LabeledCheckbox(
                    label: 'Report location',
                    value: _shouldReportLocation,
                    onChanged: (value) => setState(() {
                      _shouldReportLocation = value;
                    }),
                  ),
                ],
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(ref.watch(appStateProvider).taxiState.name),
                  Offstage(
                    offstage: _connected,
                    child: const Text('disconnected'),
                  ),
                  Offstage(
                    offstage: !_connected,
                    child: Column(
                      children: [
                        const Text('connected'),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setTaxiState(TaxiState.WAITING);
                            _reportState(TaxiState.WAITING);
                          },
                          child: const Text('state WAITING'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setTaxiState(TaxiState.RUNNING);
                            _reportState(TaxiState.RUNNING);
                          },
                          child: const Text('state RUNNING'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Offstage(
              offstage: _nearTarget != true,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(appStateProvider.notifier)
                          .setTaxiState(TaxiState.RUNNING);
                    },
                    child: const Text('픽업 완료'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
