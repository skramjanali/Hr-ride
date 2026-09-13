
enum RideStatus {
  requested,
  assigned,
  arriving,
  started,
  completed,
  cancelled,
}

class RideStateMachine {
  bool canMove(RideStatus from, RideStatus to) {
    if (to == RideStatus.cancelled &&
        from != RideStatus.completed &&
        from != RideStatus.cancelled) return true;

    const next = <RideStatus, RideStatus>{
      RideStatus.requested: RideStatus.assigned,
      RideStatus.assigned: RideStatus.arriving,
      RideStatus.arriving: RideStatus.started,
      RideStatus.started: RideStatus.completed,
    };
    return next[from] == to;
  }
}
