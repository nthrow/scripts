# see: https://forum.ethereum.org/discussion/18435/reducing-the-power-consumption-on-my-rx580-rig

#!/usr/bin/env sh
# set power_dpm_state
echo "performance" > /sys/class/drm/card0/device/power_dpm_state

# set pp_power_profile_mode
echo manual > /sys/class/drm/card0/device/power_dpm_force_performance_level
echo "5 1 0 0 0 1 0 0 0" > /sys/class/drm/card0/device/pp_power_profile_mode

# set pp_od_clk_voltage
echo "r" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "s 2 952 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "s 3 1041 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "s 4 1106 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "s 5 1168 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "s 6 1175 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "s 7 1175 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "m 2 2000 850" > /sys/class/drm/card0/device/pp_od_clk_voltage
echo "c" > /sys/class/drm/card0/device/pp_od_clk_voltage
