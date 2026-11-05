//! Seconds since boot, from /proc/uptime. None if unreadable.

pub fn read() -> Option<u64> {
    parse(&std::fs::read_to_string("/proc/uptime").ok()?)
}

/// `12345.67 54321.00` → 12345.
pub fn parse(text: &str) -> Option<u64> {
    let secs: f64 = text.split_whitespace().next()?.parse().ok()?;
    Some(secs as u64)
}

#[cfg(test)]
mod tests {
    #[test]
    fn first_number_in_whole_seconds() {
        assert_eq!(super::parse("12345.67 54321.00\n"), Some(12345));
        assert_eq!(super::parse(""), None);
    }
}
