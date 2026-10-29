/// Battery warnings use the last percentage reported with a shared location update.
const lowBatteryThresholdPercent = 20;

/// Returns true only for a valid reported percentage at or below the warning threshold.
bool isLowBattery(int? batteryLevel) =>
    batteryLevel != null && batteryLevel >= 0 && batteryLevel <= lowBatteryThresholdPercent;
