#!/usr/bin/env bash

set -euo pipefail

echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
