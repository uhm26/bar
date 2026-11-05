//! How often and how recently each app was launched ("frecency"), kept in
//! `$XDG_STATE_HOME/launcher/history`: one `id<TAB>count<TAB>last-unix-seconds` per line.

use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq)]
struct Use {
    count: u32,
    last: u64,
}

#[derive(Debug, Default)]
pub struct History {
    path: Option<PathBuf>,
    uses: HashMap<String, Use>,
}

/// Where the history lives (`None` without `$HOME`: then it's kept in memory only).
pub fn path() -> Option<PathBuf> {
    let env = |k| std::env::var(k).ok().filter(|v: &String| !v.is_empty());
    let state = env("XDG_STATE_HOME").or_else(|| env("HOME").map(|h| h + "/.local/state"))?;
    Some(PathBuf::from(state).join("launcher/history"))
}

impl History {
    /// Reads the file; a missing or broken file is an empty history (bad lines are skipped).
    pub fn load(path: Option<PathBuf>) -> Self {
        let text = path
            .as_ref()
            .and_then(|p| fs::read_to_string(p).ok())
            .unwrap_or_default();
        let uses = text.lines().filter_map(parse_line).collect();
        Self { path, uses }
    }

    pub fn bump(&mut self, id: &str, now: u64) {
        let u = self.uses.entry(id.into()).or_insert(Use {
            count: 0,
            last: now,
        });
        u.count = u.count.saturating_add(1);
        u.last = now;
    }

    /// Forgets apps that are gone (uninstalled), so the file doesn't only ever grow.
    pub fn retain(&mut self, keep: impl Fn(&str) -> bool) {
        self.uses.retain(|id, _| keep(id));
    }

    /// Writes a temp file and renames it over the old one: a crash never leaves half a file.
    pub fn save(&self) -> io::Result<()> {
        let Some(path) = &self.path else {
            return Ok(());
        };
        if let Some(dir) = path.parent() {
            fs::create_dir_all(dir)?;
        }
        let mut text = String::new();
        for (id, u) in &self.uses {
            text += &format!("{id}\t{}\t{}\n", u.count, u.last);
        }
        let tmp = path.with_extension("tmp");
        fs::write(&tmp, text)?;
        fs::rename(tmp, path)
    }

    /// Ranking bonus: launches (max 10 count) × recency weight (4 within an hour … 1 older
    /// than a week), × 4. 0..=160, so it beats a slightly better match but not a much better one.
    pub fn boost(&self, id: &str, now: u64) -> i32 {
        let Some(u) = self.uses.get(id) else { return 0 };
        let age = now.saturating_sub(u.last);
        let weight = match age {
            0..3_600 => 4,
            3_600..86_400 => 3,
            86_400..604_800 => 2,
            _ => 1,
        };
        u.count.min(10) as i32 * weight * 4
    }
}

fn parse_line(line: &str) -> Option<(String, Use)> {
    let mut f = line.split('\t');
    let (id, count, last) = (f.next()?, f.next()?.parse().ok()?, f.next()?.parse().ok()?);
    (!id.is_empty()).then(|| (id.to_string(), Use { count, last }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn save_load_roundtrip() {
        let path =
            std::env::temp_dir().join(format!("launcher-test-{}/history", std::process::id()));
        let mut h = History::load(Some(path.clone()));
        h.bump("firefox", 1000);
        h.bump("firefox", 2000);
        h.save().unwrap();
        let back = History::load(Some(path.clone()));
        assert_eq!(
            back.uses["firefox"],
            Use {
                count: 2,
                last: 2000
            }
        );
        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[test]
    fn recent_beats_old_and_bad_lines_are_skipped() {
        let h = History {
            path: None,
            uses: "a\t3\t1000000\nb\t3\t0\njunk\nc\tx\t1\n"
                .lines()
                .filter_map(parse_line)
                .collect(),
        };
        assert_eq!(h.uses.len(), 2);
        assert!(h.boost("a", 1_000_060) > h.boost("b", 1_000_060));
        assert_eq!(h.boost("missing", 0), 0);
    }
}
