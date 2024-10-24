import 'dart:async';
import 'dart:convert';

import 'package:daejeon_taxi/domain/environment/app_state_provider.dart';
import 'package:daejeon_taxi/presentation/component/labeled_checkbox.dart';
import 'package:daejeon_taxi/presentation/widget/x_map/x_map.dart';
import 'package:daejeon_taxi/res/client_event.dart';
import 'package:daejeon_taxi/res/taxi_state.dart';
import 'package:daejeon_taxi/utils/latlng.dart';
import 'package:daejeon_taxi/utils/throttler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // NMarker? _mockMarker;

  // static const _markerMockId = 'mock';

  BaechaTarget? _baechaTarget;

  /// 서버에서 배차를 제안한 타겟, 거절 시 배차 풀에 재등록
  // LatLng? _suggestedTarget;

  static const _baechaTargetOverlayId = 'target';

  NAddableOverlay? _baechaTargetOverlay;
  static const _baechaLineId = 'baecha_line';

  NPolylineOverlay? _baechaLine;

  NAddableOverlay? _baechaTooltipOverlay;

  /// in meters
  static const double _baechaTargetRadiusInMeters = 500;

  // LatLng? _targetLocation;

  /// 현재 위치
  // LatLng? _currentLocation;

  /// 타겟 범위 내에 도착하여 픽업 가능 여부
  // bool? get _nearTarget => (_currentLocation == null || _targetLocation == null)
  //     ? null
  //     : _currentLocation!.distanceTo(_targetLocation!) <=
  //         _baechaTargetRadiusInMeters;

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

  void _requestBaecha() {
    _socket.emit('request_baecha');
    ref.read(appStateProvider.notifier).setTaxiState(TaxiState.waiting);
  }

  void _cancelBaecha() {
    _socket.emit('cancel_baecha');
    ref.read(appStateProvider.notifier).setTaxiState(TaxiState.idle);
    _clearBaechaTarget();
  }

  void _pickupDone() {
    _socket.emit('pickup_done');
    ref.read(appStateProvider.notifier).setTaxiState(TaxiState.running);
    _clearBaechaTarget();
  }

  void _clearBaechaTarget() {
    _baechaTarget = null;
    if (_baechaTargetOverlay != null) {
      _controller.removeOverlay(_baechaTargetOverlay!);
      _baechaTargetOverlay = null;
    }
    if (_baechaTooltipOverlay != null) {
      _controller.removeOverlay(_baechaTooltipOverlay!);
      _baechaTooltipOverlay = null;
    }
    if (_baechaLine != null) {
      _controller.removeOverlay(_baechaLine!);
      _baechaLine = null;
    }
  }

  // void _onTargetSuggested(double lat, double lng) {
  //   setState(() {
  //     // _suggestedTarget = NLatLng(lat, lng);
  //   });
  // }

  // void _rejectTarget() {
  //   assert(_suggestedTarget != null);
  //
  //   _socket.emit('reject');
  //   setState(() {
  //     _suggestedTarget = null;
  //   });
  // }

  void _updateBaechaLine() {
    if (_controller.getCurrentLocation() == null) return;

    final lineCoords = [
      _controller.getCurrentLocation()!,
      _baechaTarget!.coords
    ];
    if (_baechaLine != null) {
      _baechaLine!.setCoords(lineCoords);
    } else {
      _baechaLine = _buildBaechaLine(lineCoords);
      _controller.addOverlay(_baechaLine!);
    }
  }

  NPolylineOverlay _buildBaechaLine(List<NLatLng> lineCoords) {
    return NPolylineOverlay(
      id: _baechaLineId,
      coords: lineCoords,
      lineCap: NLineCap.round,
      pattern: [4, 2],
      width: 4,
      color: const Color.fromARGB(255, 0x3b, 0x62, 0x8b),
    );
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

  void _showSnackBar(SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

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

        // 택시가 배차 대기중이 아니면 배차 정보 무시
        // 추후 서버단에서 배차 대기중인 택시에게만 메시지 보내도록 수정
        if (ref.read(appStateProvider).taxiState != TaxiState.waiting) {
          debugPrint('but taxi is not waiting, so ignore');
          return;
        }

        _showSnackBar(
          SnackBar(
            content: const Text('배차가 완료되었습니다.'),
            action: SnackBarAction(
              label: '확인',
              onPressed: () {},
            ),
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 8,
              left: 24,
              right: 16,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

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
            _baechaLine = _buildBaechaLine(lineCoords);
            _controller.addOverlay(_baechaLine!);
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
                      Text(
                        '${_baechaTarget!.clusterName} 주변',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('예상 수요: ${_baechaTarget!.demand.toInt()}명'),
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
      body: SafeArea(
        child: Stack(
          children: [
            XMap(
              controller: _controller,
              onMapReady: () {
                setState(() {
                  isMapReady = true;
                });
                _controller.setShouldMockLocation(true);
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
                      label: 'Show Debug UI',
                      value: ref.watch(appStateProvider).showDebugUi,
                      onChanged: (value) => setState(() {
                        ref
                            .read(appStateProvider.notifier)
                            .setShowDebugUi(value);
                      }),
                    ),
                    Offstage(
                      offstage: !ref.watch(appStateProvider).showDebugUi,
                      child: Column(
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
                                  _requestBaecha();
                                },
                                child: const Text("Request baecha"),
                              ),
                              Offstage(
                                offstage:
                                    ref.watch(appStateProvider).taxiState !=
                                        TaxiState.waiting,
                                child: const CircularProgressIndicator(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            Positioned(
              top: 0,
              right: 0,
              child: Offstage(
                offstage: !ref.watch(appStateProvider).showDebugUi,
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
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Offstage(
                offstage: _baechaTarget != null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                      ),
                      onPressed: _requestBaecha,
                      child: const Text(
                        "배차 요청",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Offstage(
                offstage: _baechaTarget == null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                            ),
                            onPressed: _cancelBaecha,
                            child: const Text(
                              "배차 취소",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                            ),
                            onPressed: _pickupDone,
                            child: const Text(
                              "픽업 완료",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
