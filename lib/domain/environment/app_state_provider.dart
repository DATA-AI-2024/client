// ignore_for_file: library_private_types_in_public_api

import 'package:daejeon_taxi/res/consts.dart';
import 'package:daejeon_taxi/res/prefs.dart';
import 'package:daejeon_taxi/res/taxi_state.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_state_provider.g.dart';

@Riverpod(keepAlive: true)
class AppState extends _$AppState {
  SharedPreferences? _prefs;

  AppState() {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      final socketUrl = prefs.getString(Prefs.socketUrl);
      if (socketUrl != null) {
        setSocketUrl(socketUrl);
      }
      final showDebugUi = prefs.getBool(Prefs.showDebugUi);
      if (showDebugUi != null) {
        setShowDebugUi(showDebugUi);
      }
    });
  }

  @override
  _AppState build() {
    return const _AppState();
  }

  void setTaxiState(TaxiState taxiState) {
    state = state.copyWith(taxiState: taxiState);
  }

  void setSocketUrl(String socketUrl) {
    state = state.copyWith(socketUrl: socketUrl);
    _prefs?.setString(Prefs.socketUrl, socketUrl);
  }

  void setShowDebugUi(bool showDebugUi) {
    state = state.copyWith(showDebugUi: showDebugUi);
  }
}

@immutable
class _AppState {
  final TaxiState taxiState;
  final String socketUrl;
  final bool showDebugUi;

  const _AppState({
    this.taxiState = TaxiState.idle,
    this.socketUrl = WS_CLIENT,
    this.showDebugUi = true,
  });

  _AppState copyWith(
      {TaxiState? taxiState, String? socketUrl, bool? showDebugUi}) {
    return _AppState(
      taxiState: taxiState ?? this.taxiState,
      socketUrl: socketUrl ?? this.socketUrl,
      showDebugUi: showDebugUi ?? this.showDebugUi,
    );
  }
}
