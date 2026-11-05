//! Per-app TCP traffic from `ss` (iproute2): one line per connected TCP socket with its
//! owner pid and byte counters. UDP has no per-socket counters in Linux, so UDP traffic
//! (voice, games, QUIC) can't be split per app without packet capture (root); the bar
//! shows it as "other" = interface total minus the apps' TCP.

use std::collections::HashMap;
use std::process::Command;

use crate::procs;

/// One TCP socket: inode (stable key between reads), owner pid, bytes since it opened.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Sock {
    pub ino: u64,
    pub pid: u32,
    pub rx: u64,
    pub tx: u64,
}

/// Bytes per socket inode, kept for the next read's deltas.
pub type Counters = HashMap<u64, (u64, u64)>;

/// All connected TCP sockets we may see (ours: other users' sockets have no pid). `ss`
/// takes ~21 ms (it maps sockets to pids by scanning /proc/*/fd), so the sampler runs it
/// only while the bar shows the list.
pub fn read() -> Vec<Sock> {
    let Ok(out) = Command::new("ss").args(["-tinpOHe", "state", "connected"]).output() else {
        return Vec::new();
    };
    String::from_utf8_lossy(&out.stdout).lines().filter_map(parse_line).collect()
}

/// Picks `pid=`, `ino:`, `bytes_received:` and `bytes_sent:` out of one `ss -O` line.
pub fn parse_line(line: &str) -> Option<Sock> {
    let field = |key: &str| -> Option<u64> {
        let at = line.find(key)? + key.len();
        let digits: String = line[at..].chars().take_while(char::is_ascii_digit).collect();
        digits.parse().ok()
    };
    Some(Sock {
        ino: field(" ino:")?,
        pid: u32::try_from(field("pid=")?).ok()?,
        rx: field("bytes_received:").unwrap_or(0),
        tx: field("bytes_sent:").unwrap_or(0),
    })
}

pub fn counters(socks: &[Sock]) -> Counters {
    socks.iter().map(|s| (s.ino, (s.rx, s.tx))).collect()
}

/// (app, down, up) bytes/s since `prev`, apps named like the process list, busiest first.
/// A socket first seen now counts from zero (its earlier bytes are not from this second).
pub fn apps(prev: &Counters, now: &[Sock], secs: f64) -> Vec<(String, f64, f64)> {
    let mut by_name: HashMap<String, (f64, f64)> = HashMap::new();
    let mut names: HashMap<u32, String> = HashMap::new(); // one /proc lookup per pid, not per socket
    for s in now {
        let Some(&(rx0, tx0)) = prev.get(&s.ino) else { continue };
        let (down, up) = (s.rx.saturating_sub(rx0), s.tx.saturating_sub(tx0));
        if down + up == 0 || secs <= 0.0 {
            continue;
        }
        let name = names
            .entry(s.pid)
            .or_insert_with(|| procs::name_of(s.pid).unwrap_or_else(|| format!("pid {}", s.pid)))
            .clone();
        let e = by_name.entry(name).or_default();
        e.0 += down as f64 / secs;
        e.1 += up as f64 / secs;
    }
    let mut list: Vec<_> = by_name.into_iter().map(|(n, (d, u))| (n, d, u)).collect();
    list.sort_by(|a, b| (b.1 + b.2).total_cmp(&(a.1 + a.2)));
    list
}

#[cfg(test)]
mod tests {
    use super::*;

    const LINE: &str = r#"0 0 1.2.3.4:5 6.7.8.9:443 users:(("Discord",pid=98444,fd=26)) uid:1000 ino:539948 sk:6001 <-> ts bytes_sent:15308 bytes_acked:15309 bytes_received:4549024 segs_out:1"#;

    #[test]
    fn parses_owner_inode_and_bytes() {
        let s = parse_line(LINE).unwrap();
        assert_eq!(s, Sock { ino: 539948, pid: 98444, rx: 4549024, tx: 15308 });
    }

    #[test]
    fn sockets_without_owner_are_skipped() {
        assert_eq!(parse_line("0 0 a:1 b:2 uid:0 ino:7 bytes_received:5"), None);
    }

    #[test]
    fn new_sockets_count_from_zero() {
        let prev = Counters::from([(1, (100, 10))]);
        let now = [Sock { ino: 1, pid: u32::MAX, rx: 300, tx: 10 }, Sock { ino: 2, pid: u32::MAX, rx: 999, tx: 0 }];
        let list = apps(&prev, &now, 2.0);
        assert_eq!(list.len(), 1);
        assert_eq!((list[0].1, list[0].2), (100.0, 0.0));
    }
}
