/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Health HAL for the Radxa Dragon Q6A.
 *
 * The Q6A is a wall-powered SBC with no battery. The kernel exposes no battery
 * power_supply node, so the stock android.hardware.health-service.example reads
 * nothing from sysfs and reports level 0 / status UNKNOWN — which surfaces as a
 * permanent 0% battery icon in the status bar.
 *
 * We subclass the default Health implementation and override UpdateHealthInfo()
 * (the documented hook; getHealthInfo() is final) to present a permanently-full,
 * AC-powered state. This binary replaces the example service via `overrides`.
 */

#include <android-base/logging.h>
#include <android/binder_interface_utils.h>
#include <health-impl/Health.h>
#include <health/utils.h>

using aidl::android::hardware::health::BatteryCapacityLevel;
using aidl::android::hardware::health::BatteryHealth;
using aidl::android::hardware::health::BatteryStatus;
using aidl::android::hardware::health::HalHealthLoop;
using aidl::android::hardware::health::Health;
using aidl::android::hardware::health::HealthInfo;

namespace {

class HealthImpl : public Health {
  public:
    using Health::Health;

  protected:
    // Called by getHealthInfo()/the health loop before values reach clients
    // (BatteryService -> status bar). Force a full, externally-powered state.
    void UpdateHealthInfo(HealthInfo* health_info) override {
        health_info->chargerAcOnline = true;
        health_info->chargerUsbOnline = false;
        health_info->chargerWirelessOnline = false;
        health_info->chargerDockOnline = false;
        health_info->batteryPresent = true;
        health_info->batteryLevel = 100;
        health_info->batteryStatus = BatteryStatus::FULL;
        health_info->batteryHealth = BatteryHealth::GOOD;
        health_info->batteryCapacityLevel = BatteryCapacityLevel::FULL;
        health_info->batteryChargeTimeToFullNowSeconds = 0;
        // Provide sane, non-zero telemetry so consumers don't flag bad readings.
        health_info->batteryTemperatureTenthsCelsius = 250;  // 25.0 C
        if (health_info->batteryVoltageMillivolts <= 0) {
            health_info->batteryVoltageMillivolts = 5000;
        }
    }
};

}  // namespace

int main() {
    auto config = std::make_unique<healthd_config>();
    ::android::hardware::health::InitHealthdConfig(config.get());
    auto binder = ndk::SharedRefBase::make<HealthImpl>("default", std::move(config));
    auto hal_health_loop = std::make_shared<HalHealthLoop>(binder, binder);
    return hal_health_loop->StartLoop();
}
