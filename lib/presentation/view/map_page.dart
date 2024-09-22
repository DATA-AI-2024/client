import 'dart:convert';

import 'package:daejeon_taxi/domain/environment/app_state_provider.dart';
import 'package:daejeon_taxi/packages/index.dart';
import 'package:daejeon_taxi/res/index.dart';
import 'package:daejeon_taxi/utils/index.dart';
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
  NaverMapController? _controller;

  /// 컨트롤러에서 지도 상 현재 위치를 받아오는 기능이 없어,
  /// 가장 마지막으로 포착된 위치를 기록하는 용으로 사용
  NLatLng? _lastLatLng;

  final _reportThrottler = Throttler(throttleGapInMillis: 500);

  final _stateThrottler = Throttler(throttleGapInMillis: 100);

  Timer? _returnTimer;

  /// 테스트용으로, 지도를 움직이면 그곳을 현재 위치로 지도에 표시하고 서버에 보고함
  bool _shouldMockLocation = true;

  /// 서버에 위치를 실시간 보고
  bool _shouldReportLocation = true;

  NMarker? _mockMarker;

  static const _markerMockId = 'mock';

  /// 서버에서 배차를 제안한 타겟, 거절 시 배차 풀에 재등록
  NLatLng? _suggestedTarget;

  static const _targetMarkerId = 'target';

  NAddableOverlay? _targetOverlay;

  /// in meters
  static const double _targetRadiusInMeters = 100;

  NLatLng? _targetLocation;

  /// 타겟 범위 내에 도착하여 픽업 가능 여부
  bool? get _nearTarget => (_lastLatLng == null || _targetLocation == null)
      ? null
      : _lastLatLng!.distanceTo(_targetLocation!) <= _targetRadiusInMeters;

  // End of map stuff

  // Start of socket stuff
  late final Socket _socket;

  /// 소켓 연결 여부
  bool _connected = false;

  // End of socket stuff

  void _cancelReturnToCurrentLocation() {
    _returnTimer?.cancel();
    _returnTimer = null;
  }

  void _returnToCurrentLocation() {
    _returnTimer?.cancel();
    _returnTimer = Timer(const Duration(seconds: 2), () async {
      if (_controller == null) {
        return;
      }
      _controller!.setLocationTrackingMode(NLocationTrackingMode.face);
    });
  }

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

  /// [reason]이 [null]일 경우 무조건 report
  void _reportLocation([NCameraUpdateReason? reason]) {
    _reportThrottler.run(() {
      // 실제로 이동했거나, 테스트 중이어서 [_shouldMockLocation]이 켜져있을 때는
      // 제스처로 인해 이동했을 때 위치를 서버에 보고함
      final shouldReportLocation = reason == null ||
          reason == NCameraUpdateReason.location ||
          (_shouldMockLocation && reason == NCameraUpdateReason.gesture);
      if (shouldReportLocation) {
        if (_lastLatLng == null) {
          return;
        }

        final location = {
          'lat': _lastLatLng!.latitude,
          'lng': _lastLatLng!.longitude,
        };
        _socket.emit(CLIENT_EVENT_UPDATE_LOCATION, jsonEncode(location));
        // debugPrint('reported');
      }
    });
  }

  /// 택시 대기 중, 운행 중 상태 보고
  void _reportState(TaxiState state) {
    _socket.emit('state', state.name);
  }

  void _onTargetSuggested(double lat, double lng) {
    setState(() {
      _suggestedTarget = NLatLng(lat, lng);
    });
  }

  void _rejectTarget() {
    assert(_suggestedTarget != null);

    _socket.emit('reject');
    setState(() {
      _suggestedTarget = null;
    });
  }

  @override
  void initState() {
    super.initState();

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
        final position = NLatLng(data['lat'], data['lng']);
        _targetLocation = position;
        if (_targetOverlay != null) {
          if (_targetOverlay is NMarker) {
            (_targetOverlay as NMarker).setPosition(position);
          } else if (_targetOverlay is NCircleOverlay) {
            (_targetOverlay as NCircleOverlay).setCenter(position);
          } else {
            // TODO: Consider other types?
          }
        } else {
          _targetOverlay = NCircleOverlay(
            id: _targetMarkerId,
            center: position,
            radius: _targetRadiusInMeters,
            color: Colors.purpleAccent.withOpacity(0.3),
          );
          _controller?.addOverlay(_targetOverlay!);
        }
      })
      ..on('hello', (data) {
        debugPrint('hello');
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
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
          NaverMap(
            options: const NaverMapViewOptions(),
            onMapReady: (controller) {
              _controller = controller;
              controller.setLocationTrackingMode(NLocationTrackingMode.face);
              final overlay = controller.getLocationOverlay();
              overlay.setIsVisible(true);
            },
            onCameraChange: (reason, animated) {
              // debugPrint('change $reason $animated ${DateTime.now()}');

              if (_controller == null) {
                return;
              }

              // 실제 이동 시 현재 위치 기록
              // 지도 상 실제 위치를 받아오는 함수를 못 찾아 [_lastLatLng]를 대신 사용
              final shouldRecordLocation =
                  reason == NCameraUpdateReason.location ||
                      (reason == NCameraUpdateReason.gesture &&
                          _shouldMockLocation);
              if (shouldRecordLocation) {
                _lastLatLng = _controller!.nowCameraPosition.target;
              }

              // 타겟 위치 범위 내에 도착 시
              debugPrint('running setState: ${_nearTarget}');
              _stateThrottler.run(() => setState(() {}));

              if (!_shouldMockLocation) {
                _cancelReturnToCurrentLocation();
              } else {
                // 테스트용으로 현재 위치를 화면이 움직인 곳으로 설정함
                _updateCurrentLocationMock(reason);
              }
              _reportLocation(reason);
            },
            onCameraIdle: () {
              debugPrint('idle ${DateTime.now()}');
              if (!_shouldMockLocation) {
                _returnToCurrentLocation();
              }
            },
          ),
          Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledCheckbox(
                  label: 'Mock location',
                  value: _shouldMockLocation,
                  onChanged: (value) => setState(() {
                    _shouldMockLocation = value;
                  }),
                ),
                _LabeledCheckbox(
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

class _LabeledCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _LabeledCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              visualDensity: VisualDensity.compact,
              value: value,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
