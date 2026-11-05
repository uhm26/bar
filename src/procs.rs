//! Processes from /proc/<pid>/{stat,statm,exe}, grouped by name.
//! Read errors per process are skipped: processes vanish between listing and reading.

use std::collections::{HashMap, HashSet};
use std::fs;

/// x86_64 Linux page size; statm counts pages.
const PAGE: u64 = 4096;

/// Programs that run scripts: their processes keep the script's own name (comm).
const INTERPRETERS: [&str; 9] = [
    "bash", "sh", "dash", "zsh", "fish", "node", "perl", "ruby", "java",
];

pub struct Sample {
    pub pid: u32,
    pub name: String,
    /// utime + stime, USER_HZ ticks since the process started.
    pub ticks: u64,
    /// Resident memory in bytes.
    pub rss: u64,
}

/// All processes with a name, cpu share (% of machine) and memory, summed by name.
#[derive(Clone, Debug, PartialEq)]
pub struct Group {
    pub name: String,
    pub cpu: f64,
    pub mem: u64,
    /// Every process in the group, so the bar can end or kill them all.
    pub pids: Vec<u32>,
}

/// Every user process right now. Kernel threads (no resident memory) are left out.
pub fn read_all() -> Vec<Sample> {
    let Ok(dir) = fs::read_dir("/proc") else {
        return Vec::new();
    };
    dir.flatten()
        .filter_map(|e| e.file_name().to_str()?.parse::<u32>().ok())
        .filter_map(read_one)
        .filter(|s| s.rss > 0)
        .collect()
}

fn read_one(pid: u32) -> Option<Sample> {
    let stat = read_lossy(&format!("/proc/{pid}/stat"))?;
    let statm = fs::read_to_string(format!("/proc/{pid}/statm")).ok()?;
    let (comm, ticks) = parse_stat(&stat)?;
    let rss = statm.split_whitespace().nth(1)?.parse::<u64>().ok()? * PAGE;
    if rss == 0 {
        return None; // kernel thread: left out anyway, skip the exe lookup
    }
    let exe = fs::read_link(format!("/proc/{pid}/exe")).ok();
    let name = pick_name(comm, exe.as_deref().and_then(|p| p.to_str()));
    Some(Sample {
        pid,
        name,
        ticks,
        rss,
    })
}

/// A /proc text file; names may not be UTF-8 (comm is raw bytes), so decode lossily
/// instead of dropping the process.
fn read_lossy(path: &str) -> Option<String> {
    fs::read(path).ok().map(|b| String::from_utf8_lossy(&b).into_owned())
}

/// Display name for one pid, the same way the process list names it (None if it is gone).
pub fn name_of(pid: u32) -> Option<String> {
    let comm = read_lossy(&format!("/proc/{pid}/comm"))?;
    let exe = fs::read_link(format!("/proc/{pid}/exe")).ok();
    Some(pick_name(comm.trim().to_string(), exe.as_deref().and_then(|p| p.to_str())))
}

/// The program's file name, so helper processes group under their app (Firefox's
/// "Isolated Web Co" → "firefox"). Falls back to comm when the exe is unreadable (other
/// users' processes), is an interpreter, or has no letters (claude's exe is "2.1.316").
pub fn pick_name(comm: String, exe: Option<&str>) -> String {
    let Some(path) = exe else { return comm };
    let path = path.strip_suffix(" (deleted)").unwrap_or(path);
    let base = path.rsplit('/').next().unwrap_or(path);
    let interpreter =
        INTERPRETERS.contains(&base) || base.starts_with("python") || base.starts_with("lua");
    if base.is_empty() || interpreter || !base.chars().any(char::is_alphabetic) {
        return comm;
    }
    base.to_string()
}

/// `pid (comm) state ... utime stime ...`. comm may hold spaces and ')', so split at the last ')'.
pub fn parse_stat(stat: &str) -> Option<(String, u64)> {
    let open = stat.find('(')?;
    let close = stat.rfind(')')?;
    let name = stat.get(open + 1..close)?.to_string();
    let rest: Vec<&str> = stat.get(close + 1..)?.split_whitespace().collect();
    // rest[0] is field 3 (state); utime and stime are fields 14 and 15.
    let utime: u64 = rest.get(11)?.parse().ok()?;
    let stime: u64 = rest.get(12)?.parse().ok()?;
    Some((name, utime + stime))
}

/// pid → ticks, kept for the next sample's deltas.
pub fn ticks(samples: &[Sample]) -> HashMap<u32, u64> {
    samples.iter().map(|s| (s.pid, s.ticks)).collect()
}

/// Sum by name. cpu = ticks since `prev` / all cpu ticks in that time (`total`).
/// New processes count from zero, so their first second shows no cpu.
/// `session` pids still count in cpu/mem but are left out of `pids`, so the bar can never
/// signal them (see `session_chain`).
pub fn group(
    prev: &HashMap<u32, u64>,
    now: &[Sample],
    total: u64,
    session: &HashSet<u32>,
) -> Vec<Group> {
    let mut by_name: HashMap<&str, Group> = HashMap::new();
    for s in now {
        let delta = prev.get(&s.pid).map_or(0, |p| s.ticks.saturating_sub(*p));
        let g = by_name.entry(&s.name).or_insert_with(|| Group {
            name: s.name.clone(),
            cpu: 0.0,
            mem: 0,
            pids: Vec::new(),
        });
        g.cpu += if total == 0 {
            0.0
        } else {
            delta as f64 * 100.0 / total as f64
        };
        g.mem += s.rss;
        if !session.contains(&s.pid) {
            g.pids.push(s.pid);
        }
    }
    by_name.into_values().collect()
}

/// Pids the bar must never signal: Hyprland and its parents (start-hyprland → login shell →
/// login), plus our own parents (qs, ...). Killing any of these ends the session or the bar,
/// and the login shell hides inside the harmless-looking "bash" row, so block them by pid.
/// Both chains: a bar started by hand gets re-parented to init and its own chain is just
/// systemd (seen live), so ours alone would miss the login shell.
pub fn session_chain() -> HashSet<u32> {
    let mut chain = HashSet::new();
    let compositors = fs::read_dir("/proc")
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let pid: u32 = e.file_name().to_str()?.parse().ok()?;
            let comm = read_lossy(&format!("/proc/{pid}/comm"))?;
            (comm.trim() == "Hyprland").then_some(pid)
        });
    for start in compositors.collect::<Vec<_>>() {
        chain.insert(start);
        add_parents(start, &mut chain);
    }
    add_parents(std::process::id(), &mut chain);
    chain
}

fn add_parents(mut pid: u32, chain: &mut HashSet<u32>) {
    while pid > 1 {
        let Some(parent) = read_lossy(&format!("/proc/{pid}/stat"))
            .and_then(|s| parse_ppid(&s))
        else {
            break;
        };
        chain.insert(parent);
        pid = parent;
    }
}

/// Field 4 of /proc/<pid>/stat (after the comm in parens).
pub fn parse_ppid(stat: &str) -> Option<u32> {
    stat.get(stat.rfind(')')? + 1..)?
        .split_whitespace()
        .nth(1)?
        .parse()
        .ok()
}

/// The top `n` by cpu plus the top `n` by memory, each group once, highest cpu first.
pub fn top(mut groups: Vec<Group>, n: usize) -> Vec<Group> {
    groups.sort_by_key(|g| std::cmp::Reverse(g.mem));
    let mut keep: Vec<Group> = groups.iter().take(n).cloned().collect();
    groups.sort_by(|a, b| b.cpu.total_cmp(&a.cpu));
    for g in groups.into_iter().take(n) {
        if !keep.iter().any(|k| k.name == g.name) {
            keep.push(g);
        }
    }
    keep.sort_by(|a, b| b.cpu.total_cmp(&a.cpu));
    keep
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(pid: u32, name: &str, ticks: u64, rss: u64) -> Sample {
        Sample {
            pid,
            name: name.into(),
            ticks,
            rss,
        }
    }

    #[test]
    fn stat_name_may_hold_spaces_and_parens() {
        let stat = "42 (Web (Content) x) S 1 2 3 4 5 6 7 8 9 10 30 12 0 0";
        assert_eq!(parse_stat(stat), Some(("Web (Content) x".into(), 42)));
    }

    #[test]
    fn ppid_is_field_four_after_the_name() {
        assert_eq!(parse_ppid("42 (a) b) S 7 1 1"), Some(7));
        assert_eq!(parse_ppid("garbage"), None);
    }

    #[test]
    fn name_is_the_program_unless_that_says_nothing() {
        let pick = |comm: &str, exe| pick_name(comm.into(), exe);
        assert_eq!(
            pick("Isolated Web Co", Some("/usr/lib/firefox/firefox")),
            "firefox"
        );
        assert_eq!(pick("foo", Some("/usr/bin/foo (deleted)")), "foo");
        assert_eq!(
            pick(
                "claude",
                Some("/home/u/.local/share/claude/versions/2.1.316")
            ),
            "claude"
        );
        assert_eq!(pick("myscript", Some("/usr/bin/python3.13")), "myscript");
        assert_eq!(pick("deploy.sh", Some("/usr/bin/bash")), "deploy.sh");
        assert_eq!(pick("systemd", None), "systemd");
    }

    #[test]
    fn groups_sum_cpu_and_memory_by_name() {
        let prev = HashMap::from([(1, 100), (2, 50)]);
        let now = [
            sample(1, "a", 110, 10),
            sample(2, "a", 60, 5),
            sample(3, "b", 999, 7),
        ];
        let mut g = group(&prev, &now, 100, &HashSet::from([2]));
        g.sort_by(|x, y| x.name.cmp(&y.name));
        assert_eq!(
            g[0],
            Group {
                name: "a".into(),
                cpu: 20.0,
                mem: 15,
                pids: vec![1] // pid 2 is in the session chain: counted, never killable
            }
        );
        assert_eq!(g[1].cpu, 0.0); // new process: no previous sample
    }

    #[test]
    fn top_keeps_heavy_cpu_and_heavy_memory_once() {
        let g = |name: &str, cpu, mem| Group {
            name: name.into(),
            cpu,
            mem,
            pids: vec![1],
        };
        let all = vec![
            g("cpu", 50.0, 1),
            g("mem", 0.0, 900),
            g("both", 40.0, 800),
            g("idle", 0.0, 2),
        ];
        let names: Vec<String> = top(all, 2).into_iter().map(|g| g.name).collect();
        assert_eq!(names, ["cpu", "both", "mem"]);
    }
}
