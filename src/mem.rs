//! RAM and swap from /proc/meminfo, in bytes.

use std::fmt;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Mem {
    pub used: u64,
    pub total: u64,
    pub swap_used: u64,
    pub swap_total: u64,
}

#[derive(Debug)]
pub enum Error {
    Read(std::io::Error),
    Parse(&'static str),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Error::Read(e) => write!(f, "read /proc/meminfo: {e}"),
            Error::Parse(key) => write!(f, "parse /proc/meminfo: no {key}"),
        }
    }
}

pub fn read() -> Result<Mem, Error> {
    let text = std::fs::read_to_string("/proc/meminfo").map_err(Error::Read)?;
    parse(&text)
}

/// Used = total - available (what the kernel could free counts as free).
pub fn parse(info: &str) -> Result<Mem, Error> {
    let total = field(info, "MemTotal")?;
    let available = field(info, "MemAvailable")?;
    let swap_total = field(info, "SwapTotal")?;
    let swap_free = field(info, "SwapFree")?;
    Ok(Mem {
        used: total.saturating_sub(available),
        total,
        swap_used: swap_total.saturating_sub(swap_free),
        swap_total,
    })
}

/// `Key:   123 kB` → bytes.
fn field(info: &str, key: &'static str) -> Result<u64, Error> {
    info.lines()
        .find_map(|l| l.strip_prefix(key)?.strip_prefix(':'))
        .and_then(|rest| rest.split_whitespace().next()?.parse::<u64>().ok())
        .map(|kb| kb * 1024)
        .ok_or(Error::Parse(key))
}

#[cfg(test)]
mod tests {
    use super::*;

    const INFO: &str = "MemTotal:       16000 kB\nMemFree:  1 kB\nMemAvailable:   10000 kB\nSwapTotal:  8000 kB\nSwapFree:   7000 kB\n";

    #[test]
    fn used_is_total_minus_available() {
        let m = parse(INFO).unwrap();
        assert_eq!(m.used, 6000 * 1024);
        assert_eq!(m.total, 16000 * 1024);
        assert_eq!(m.swap_used, 1000 * 1024);
    }

    #[test]
    fn missing_key_is_an_error() {
        assert!(matches!(parse("MemTotal: 1 kB\n"), Err(Error::Parse("MemAvailable"))));
    }
}
