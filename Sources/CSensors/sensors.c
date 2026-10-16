#include "CSensors.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

// ---- Private IOHIDEventSystem declarations ---------------------------------
// These symbols live in the IOKit framework but are not in the public headers.
// Declaring them here lets us link against them directly (the same technique
// open-source menu-bar monitors use). Prototypes are stable across macOS.

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type,
                                          int32_t options, int64_t timestamp);
double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)

// Apple HID usage page/usage for thermal sensors.
#define kHIDPage_AppleVendor 0xff00
#define kHIDUsage_AppleVendor_TemperatureSensor 5

static CFDictionaryRef cs_make_temperature_matching(void) {
    int page = kHIDPage_AppleVendor;
    int usage = kHIDUsage_AppleVendor_TemperatureSensor;

    CFNumberRef pageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);

    const void *keys[]   = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *values[] = { pageNum, usageNum };

    CFDictionaryRef dict = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                              &kCFTypeDictionaryKeyCallBacks,
                                              &kCFTypeDictionaryValueCallBacks);
    CFRelease(pageNum);
    CFRelease(usageNum);
    return dict;
}

double cs_cpu_temperature_celsius(void) {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return -1.0;

    CFDictionaryRef match = cs_make_temperature_matching();
    IOHIDEventSystemClientSetMatching(client, match);
    CFRelease(match);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) {
        CFRelease(client);
        return -1.0;
    }

    double sum = 0.0;
    long valid = 0;
    CFIndex count = CFArrayGetCount(services);
    for (CFIndex i = 0; i < count; i++) {
        IOHIDServiceClientRef svc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        if (!svc) continue;
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(svc, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;
        double temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);
        // Discard obviously invalid readings.
        if (temp > 1.0 && temp < 130.0) {
            sum += temp;
            valid++;
        }
    }

    CFRelease(services);
    CFRelease(client);

    if (valid == 0) return -1.0;
    return sum / (double)valid;
}

double cs_battery_temperature_celsius(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                       IOServiceMatching("AppleSmartBattery"));
    if (!service) return -1.0;

    double result = -1.0;
    CFTypeRef prop = IORegistryEntryCreateCFProperty(service, CFSTR("Temperature"),
                                                     kCFAllocatorDefault, 0);
    if (prop) {
        if (CFGetTypeID(prop) == CFNumberGetTypeID()) {
            long raw = 0;
            CFNumberGetValue((CFNumberRef)prop, kCFNumberLongType, &raw);
            // AppleSmartBattery reports temperature in hundredths of a degree C.
            result = (double)raw / 100.0;
        }
        CFRelease(prop);
    }
    IOObjectRelease(service);
    return result;
}
