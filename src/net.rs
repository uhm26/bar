//! Network throughput from /proc/net/dev: bytes received and sent by the real network
//! cards. Rates come from two reads (see sampler).

/// Cumulative bytes since boot.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Bytes {
    pub rx: u64,
    pub tx: u64,
}

pub fn read() -> Option<Bytes> {
    let text = std::fs::read_to_string("/proc/net/dev").ok()?;
    Some(parse(&text, |name| std::path::Path::new("/sys/class/net").join(name).join("device").exists()))
}

/// `  name: rx_bytes rx_packets ... (8 rx fields) tx_bytes ...`; the two header lines and
/// interfaces `physical` rejects are skipped. Only hardware cards have a `device` link in
/// sysfs: loopback, docker, veth, bridges, VPN tunnels would count the same bytes twice.
pub fn parse(text: &str, physical: impl Fn(&str) -> bool) -> Bytes {
    let mut sum = Bytes::default();
    for line in text.lines() {
        let Some((name, rest)) = line.split_once(':') else { continue };
        if !physical(name.trim()) {
            continue;
        }
        let fields: Vec<u64> = rest.split_whitespace().filter_map(|f| f.parse().ok()).collect();
        if fields.len() >= 9 {
            sum.rx += fields[0];
            sum.tx += fields[8];
        }
    }
    sum
}

/// Bytes per second between two reads `secs` apart. Counters that went down (interface
/// reset) give 0, not a huge number.
pub fn rate(prev: Bytes, now: Bytes, secs: f64) -> (f64, f64) {
    if secs <= 0.0 {
        return (0.0, 0.0);
    }
    let per = |a: u64, b: u64| b.saturating_sub(a) as f64 / secs;
    (per(prev.rx, now.rx), per(prev.tx, now.tx))
}

#[cfg(test)]
mod tests {
    use super::*;

    const DEV: &str = "Inter-|   Receive  |  Transmit\n face |bytes packets|bytes\n    lo: 500 1 0 0 0 0 0 0 500 1 0 0 0 0 0 0\nenp5s0: 1000 9 0 0 0 0 0 0 300 4 0 0 0 0 0 0\n  wlo1: 24 1 0 0 0 0 0 0 6 1 0 0 0 0 0 0\n";

    #[test]
    fn sums_only_physical_cards() {
        assert_eq!(parse(DEV, |n| n != "lo"), Bytes { rx: 1024, tx: 306 });
        assert_eq!(parse(DEV, |n| n == "wlo1"), Bytes { rx: 24, tx: 6 });
    }

    #[test]
    fn rate_per_second_and_no_negative() {
        let a = Bytes { rx: 1000, tx: 100 };
        assert_eq!(rate(a, Bytes { rx: 3000, tx: 50 }, 2.0), (1000.0, 0.0));
        assert_eq!(rate(a, a, 0.0), (0.0, 0.0));
    }
}
