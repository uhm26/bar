//! The report as one JSON line (format: see lib.rs).

use std::fmt::Write;

use crate::sampler::Report;

pub fn render(r: &Report) -> String {
    let mut s = String::with_capacity(2048);
    let temp = r.temp.map_or("null".to_string(), |t| format!("{t:.1}"));
    let up = r.up.map_or("null".to_string(), |u| u.to_string());
    let net = r.net.map_or("null".to_string(), |(d, u, b)| format!("[{d:.0},{u:.0},{},{}]", b.rx, b.tx));
    let m = &r.mem;
    // Writing to a String cannot fail.
    let _ = write!(
        s,
        r#"{{"cpu":{:.1},"temp":{temp},"up":{up},"net":{net},"mem":[{},{}],"swap":[{},{}],"procs":"#,
        r.cpu, m.used, m.total, m.swap_used, m.swap_total
    );
    // Lists that are switched off are null, not [], so the bar keeps its last list.
    match &r.procs {
        None => s.push_str("null"),
        Some(list) => {
            s.push('[');
            for (i, p) in list.iter().enumerate() {
                let comma = if i == 0 { "" } else { "," };
                let _ = write!(s, "{comma}[{},{:.1},{},[", string(&p.name), p.cpu, p.mem);
                for (j, pid) in p.pids.iter().enumerate() {
                    let _ = write!(s, "{}{pid}", if j == 0 { "" } else { "," });
                }
                s.push_str("]]");
            }
            s.push(']');
        }
    }
    s.push_str(",\"apps\":");
    match &r.apps {
        None => s.push_str("null"),
        Some(list) => {
            s.push('[');
            for (i, (name, down, up)) in list.iter().enumerate() {
                let comma = if i == 0 { "" } else { "," };
                let _ = write!(s, "{comma}[{},{down:.0},{up:.0}]", string(name));
            }
            s.push(']');
        }
    }
    s.push('}');
    s
}

/// A JSON string literal: quotes, backslashes and control characters escaped.
pub fn string(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if (c as u32) < 0x20 => {
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{mem::Mem, procs::Group};

    #[test]
    fn escapes_quotes_backslashes_and_controls() {
        assert_eq!(string("a\"b\\c\n"), r#""a\"b\\c\u000a""#);
    }

    #[test]
    fn lists_switched_off_are_null() {
        let r = Report {
            cpu: 0.0,
            temp: None,
            up: None,
            net: None,
            apps: None,
            mem: Mem { used: 0, total: 0, swap_used: 0, swap_total: 0 },
            procs: None,
        };
        assert!(render(&r).ends_with(r#""procs":null,"apps":null}"#));
    }

    #[test]
    fn renders_one_line() {
        let r = Report {
            cpu: 12.34,
            temp: None,
            up: Some(7),
            net: Some((1536.4, 0.0, crate::net::Bytes { rx: 9, tx: 8 })),
            apps: Some(vec![("fi\"sh".into(), 2.0, 1.0)]),
            mem: Mem {
                used: 1,
                total: 2,
                swap_used: 3,
                swap_total: 4,
            },
            procs: Some(vec![Group {
                name: "fish".into(),
                cpu: 0.5,
                mem: 9,
                pids: vec![4, 5],
            }]),
        };
        assert_eq!(
            render(&r),
            r#"{"cpu":12.3,"temp":null,"up":7,"net":[1536,0,9,8],"mem":[1,2],"swap":[3,4],"procs":[["fish",0.5,9,[4,5]]],"apps":[["fi\"sh",2,1]]}"#
        );
    }
}
