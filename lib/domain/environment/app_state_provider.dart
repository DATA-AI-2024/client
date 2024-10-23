// ignore_for_file: library_private_types_in_public_api

import 'package:daejeon_taxi/res/consts.dart';
import 'package:daejeon_taxi/res/taxi_state.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_state_provider.g.dart';

@Riverpod(keepAlive: true)
class AppState extends _$AppState {
  @override
  _AppState build() {
    return const _AppState();
  }

  void setTaxiState(TaxiState taxiState) {
    state = state.copyWith(taxiState: taxiState);
  }

  void setSocketUrl(String socketUrl) {
    state = state.copyWith(socketUrl: socketUrl);
  }
}

@immutable
class _AppState {
  final TaxiState taxiState;
  final String socketUrl;

  const _AppState({
    this.taxiState = TaxiState.idle,
    this.socketUrl = WS_CLIENT,
  });

  _AppState copyWith({TaxiState? taxiState, String? socketUrl}) {
    return _AppState(
      taxiState: taxiState ?? this.taxiState,
      socketUrl: socketUrl ?? this.socketUrl,
    );
  }
}
