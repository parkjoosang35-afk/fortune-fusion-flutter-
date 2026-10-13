enum NativeWebShareOutcome { shared, cancelled, unavailable }

bool needsShareCopy(NativeWebShareOutcome outcome) =>
    outcome == NativeWebShareOutcome.unavailable;
