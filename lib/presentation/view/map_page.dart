import 'dart:async';
import 'dart:convert';

import 'package:daejeon_taxi/domain/environment/app_state_provider.dart';
import 'package:daejeon_taxi/presentation/component/labeled_checkbox.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/x_map.dart';
import 'package:daejeon_taxi/res/client_event.dart';
import 'package:daejeon_taxi/res/taxi_state.dart';
import 'package:daejeon_taxi/utils/extension/latlng.dart';
import 'package:daejeon_taxi/utils/latlng.dart';
import 'package:daejeon_taxi/utils/throttler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart';

class BaechaTarget {
  final NLatLng coords;
  final String clusterName;
  final double demand;
  final String reason;

  BaechaTarget({
    required this.coords,
    required this.clusterName,
    required this.demand,
    required this.reason,
  });
}

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  // Start of map stuff
  late final XMapController _controller;

  bool isMapReady = false;

  final _reportThrottler =
      Throttler(throttleGapInMillis: 500, runLastAttemptedAction: true);

  /// 서버에 위치를 실시간 보고
  bool _shouldReportLocation = true;

  NMarker? _mockMarker;

  static const _markerMockId = 'mock';

  BaechaTarget? _baechaTarget;

  /// 서버에서 배차를 제안한 타겟, 거절 시 배차 풀에 재등록
  LatLng? _suggestedTarget;

  static const _baechaTargetOverlayId = 'target';

  NAddableOverlay? _baechaTargetOverlay;
  static const _baechaLineId = 'baecha_line';

  NPolylineOverlay? _baechaLine;

  NAddableOverlay? _baechaTooltipOverlay;

  /// in meters
  static const double _baechaTargetRadiusInMeters = 500;

  LatLng? _targetLocation;

  /// 현재 위치
  LatLng? _currentLocation;

  /// 타겟 범위 내에 도착하여 픽업 가능 여부
  bool? get _nearTarget => (_currentLocation == null || _targetLocation == null)
      ? null
      : _currentLocation!.distanceTo(_targetLocation!) <=
          _baechaTargetRadiusInMeters;

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
  void _forceSetState(TaxiState state) {
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

  void _updateBaechaLine() {
    if (_controller.getCurrentLocation() == null) return;

    final lineCoords = [
      _controller.getCurrentLocation()!,
      _baechaTarget!.coords
    ];
    if (_baechaLine != null) {
      _baechaLine!.setCoords(lineCoords);
    } else {
      _controller.addOverlay(NPolylineOverlay(
          id: _baechaLineId, coords: lineCoords, color: Colors.red));
    }
  }

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

  @override
  void initState() {
    super.initState();

    _controller = XMapController();

    final socketUrl = ref.read(appStateProvider).socketUrl;
    final socketOption = OptionBuilder().setTransports(['websocket']).build();
    _socket = io(socketUrl, socketOption);

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

        ref.read(appStateProvider.notifier).setTaxiState(TaxiState.running);

        _baechaTarget = BaechaTarget(
            coords: NLatLng(data['lat'], data['lng']),
            clusterName: data['cluster_name'],
            demand: data['demand'],
            reason: data['reason']);

        // 배차된 클러스터에 원 오버레이 표시
        if (_baechaTargetOverlay != null) {
          // 배차된 클러스터 오버레이 타입은 Marker/Circle 중 하나라고 가정
          if (_baechaTargetOverlay is NMarker) {
            (_baechaTargetOverlay as NMarker)
                .setPosition(_baechaTarget!.coords);
          } else if (_baechaTargetOverlay is NCircleOverlay) {
            (_baechaTargetOverlay as NCircleOverlay)
                .setCenter(_baechaTarget!.coords);
          }
        } else {
          _baechaTargetOverlay = NCircleOverlay(
            id: _baechaTargetOverlayId,
            center: _baechaTarget!.coords,
            radius: _baechaTargetRadiusInMeters,
            color: Colors.purpleAccent.withOpacity(0.3),
          );
        }
        _controller.addOverlay(_baechaTargetOverlay!);

        if (_controller.getCurrentLocation() != null) {
          // 배차된 클러스터까지의 직선거리 오버레이 표시
          final lineCoords = [
            _controller.getCurrentLocation()!,
            _baechaTarget!.coords
          ];
          if (_baechaLine != null) {
            _baechaLine!.setCoords(lineCoords);
          } else {
            _controller.addOverlay(NPolylineOverlay(
                id: _baechaLineId, coords: lineCoords, color: Colors.red));
          }

          // 배차된 클러스터 위에 예상 수요량, 배차 이유 등 정보 표시
          NOverlayImage.fromWidget(
            widget: Container(
              padding: const EdgeInsets.all(8),
              child: Container(
                clipBehavior: Clip.none,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 4,
                      offset: const Offset(0, 2), // changes position of shadow
                    ),
                  ],
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Cluster ${_baechaTarget!.clusterName}'),
                      Text('예상 수요: ${_baechaTarget!.demand.toInt()}'),
                      Text(_baechaTarget!.reason),
                    ],
                  ),
                ),
              ),
            ),
            size: const Size(160, 90),
            context: context,
          ).then((overlay) {
            if (_baechaTooltipOverlay != null) {
              _controller.removeOverlay(_baechaTooltipOverlay!);
            }
            _baechaTooltipOverlay = NMarker(
              id: "icon_test",
              position: NLatLng(
                addMetersToLongitude(_baechaTarget!.coords.latitude,
                    _baechaTargetRadiusInMeters),
                _baechaTarget!.coords.longitude,
              ),
              icon: overlay,
            );
            _controller.addOverlay(_baechaTooltipOverlay!);
            // TODO: 상황에 따라 필요 시 툴팁 제거
          });
        }
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
              if (_baechaTarget != null) {
                _updateBaechaLine();
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _socket.emit('request_baecha');
                          ref
                              .read(appStateProvider.notifier)
                              .setTaxiState(TaxiState.waiting);
                        },
                        child: const Text("Request baecha"),
                      ),
                      Offstage(
                        offstage: ref.watch(appStateProvider).taxiState !=
                            TaxiState.waiting,
                        child: const CircularProgressIndicator(),
                      ),
                    ],
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
                                .setTaxiState(TaxiState.idle);
                            _forceSetState(TaxiState.idle);
                          },
                          child: const Text('Force set IDLE'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setTaxiState(TaxiState.waiting);
                            _forceSetState(TaxiState.waiting);
                          },
                          child: const Text('Force set WAITING'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setTaxiState(TaxiState.running);
                            _forceSetState(TaxiState.running);
                          },
                          child: const Text('Force set RUNNING'),
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
                          .setTaxiState(TaxiState.running);
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
