#ifndef CSENSORS_H
#define CSENSORS_H

#include <stdbool.h>

// Average temperature (°C) across the Apple thermal sensors exposed by the
// IOHID event system. Returns a negative value if no sensor could be read.
//
// This mirrors how CleanMyMac's HealthMonitor sources CPU/SoC temperature on
// Apple Silicon: there is no official public API, so it reads the private
// IOHIDEventSystem temperature sensors (page kHIDPage_AppleVendor = 0xff00,
// usage = temperature). The call needs no entitlement and works unsandboxed.
double cs_cpu_temperature_celsius(void);

// Battery temperature (°C) from IOKit AppleSmartBattery, or negative if
// unavailable (e.g. desktop Macs).
double cs_battery_temperature_celsius(void);

#endif /* CSENSORS_H */
