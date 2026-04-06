enum PriorityMode { sleep, deadline }

PriorityMode priorityModeFromSleepFlag(bool isSleepPriority) {
  return isSleepPriority ? PriorityMode.sleep : PriorityMode.deadline;
}

PriorityMode parsePriorityMode(String? raw) {
  switch (raw) {
    case 'sleep':
      return PriorityMode.sleep;
    case 'deadline':
      return PriorityMode.deadline;
    default:
      return PriorityMode.sleep;
  }
}

extension PriorityModeLabel on PriorityMode {
  String get label {
    switch (this) {
      case PriorityMode.sleep:
        return 'Sleep Priority';
      case PriorityMode.deadline:
        return 'Deadline Priority';
    }
  }

  bool get isSleepPriority => this == PriorityMode.sleep;
}
