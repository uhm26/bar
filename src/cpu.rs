//! Whole-machine cpu usage from the first line of /proc/stat.

use std::fmt;

/// Cumulative cpu time in USER_HZ ticks.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Times {
    pub busy: u64,
    pub total: u64,
}

#[derive(Debug)]
pub enum Error {
    Read(std::io::Error),
    Parse,
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Error::Read(e) => write!(f, "read /proc/stat: {e}"),
            Error::Parse => write!(f, "parse /proc/stat: no cpu line"),
        }
    }
}

pub fn read() -> Result<Times, Error> {
    let text = std::fs::read_to_string("/proc/stat").map_err(Error::Read)?;
    parse(&text).ok_or(Error::Parse)
}

/// `cpu  user nice system idle iowait irq softirq steal ...`: idle + iowait are not busy.
pub fn parse(stat: &str) -> Option<Times> {
    let line = stat.lines().find(|l| l.starts_with("cpu "))?;
    let n: Vec<u64> = line.split_whitespace().skip(1).take(8).filter_map(|v| v.parse().ok()).collect();
    if n.len() < 5 {
        return None;
    }
    let total: u64 = n.iter().sum();
    Some(Times { busy: total - n[3] - n[4], total })
}

/// Busy share between two samples, 0..100.
pub fn usage(prev: &Times, now: &Times) -> f64 {
    let total = now.total.saturating_sub(prev.total);
    if total == 0 {
        return 0.0;
    }
    now.busy.saturating_sub(prev.busy) as f64 * 100.0 / total as f64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_first_cpu_line() {
        let t = parse("cpu  10 0 10 70 10 0 0 0 0 0\ncpu0 1 1 1 1 1\n").unwrap();
        assert_eq!(t, Times { busy: 20, total: 100 });
    }

    #[test]
    fn usage_is_busy_share_of_delta() {
        let a = Times { busy: 20, total: 100 };
        let b = Times { busy: 70, total: 300 };
        assert_eq!(usage(&a, &b), 25.0);
        assert_eq!(usage(&a, &a), 0.0);
    }
}
