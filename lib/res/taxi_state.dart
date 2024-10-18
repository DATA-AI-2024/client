enum TaxiState {
  /// 평상 시거나 승객을 픽업하여 운행 중임. 배차가 필요 없음.
  idle,

  /// 배차 대기 중.
  waiting,

  /// 배차를 받아 승객을 픽업하러 가고 있음.
  running,
}
