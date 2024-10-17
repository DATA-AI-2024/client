// ignore_for_file: library_private_types_in_public_api

import 'package:daejeon_taxi/res/taxi_state.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_state_provider.g.dart';

@riverpod
class AppState extends _$AppState {
  @override
  _AppState build() {
    return const _AppState();
  }

  void setTaxiState(TaxiState taxiState) {
    state = state.copyWith(taxiState: taxiState);
  }
}

@immutable
class _AppState {
  final TaxiState taxiState;

  const _AppState({this.taxiState = TaxiState.WAITING});

  _AppState copyWith({TaxiState? taxiState}) {
    return _AppState(taxiState: taxiState ?? this.taxiState);
  }
}
