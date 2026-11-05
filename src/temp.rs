//! Cpu temperature from hwmon: AMD (`k10temp` Tctl, `zenpower` Tdie) or Intel (`coretemp`
//! package). None on machines without one of these.

use std::fs;
use std::path::{Path, PathBuf};

/// hwmon drivers whose `temp1_input` is the whole-CPU temperature.
const CPU_SENSORS: [&str; 3] = ["k10temp", "zenpower", "coretemp"];

/// The CPU sensor's `temp1_input`, found once at startup (hwmon numbers move).
pub fn find() -> Option<PathBuf> {
    fs::read_dir("/sys/class/hwmon").ok()?.flatten().map(|e| e.path()).find_map(|dir| {
        let name = fs::read_to_string(dir.join("name")).ok()?;
        is_cpu(name.trim()).then(|| dir.join("temp1_input"))
    })
}

fn is_cpu(hwmon_name: &str) -> bool {
    CPU_SENSORS.contains(&hwmon_name)
}

/// Millidegrees in the file → °C.
pub fn read(path: &Path) -> Option<f64> {
    let milli: f64 = fs::read_to_string(path).ok()?.trim().parse().ok()?;
    Some(milli / 1000.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn amd_and_intel_sensors_count_gpu_and_nvme_do_not() {
        assert!(is_cpu("k10temp") && is_cpu("coretemp") && is_cpu("zenpower"));
        assert!(!is_cpu("amdgpu") && !is_cpu("nvme") && !is_cpu("acpitz"));
    }
}
