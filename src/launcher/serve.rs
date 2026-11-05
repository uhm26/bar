//! The stdin/stdout loop (protocol: see lib.rs). One thread; idle = blocked on read.

use std::io::{self, BufRead, Write};
use std::time::{SystemTime, UNIX_EPOCH};

use super::apps::{self, App};
use super::history::{self, History};
use super::{launch, rank};
use crate::json::string;

pub fn run() -> io::Result<()> {
    let dirs = apps::dirs();
    let mut apps = apps::scan(&dirs);
    let mut history = History::load(history::path());
    let terminal = std::env::var("TERMINAL").unwrap_or_else(|_| "term".into());
    let mut out = io::stdout().lock();
    for line in io::stdin().lock().lines() {
        let line = line?;
        let mut chars = line.chars();
        let cmd = chars.next();
        let arg = chars.as_str();
        match cmd {
            Some('q') => writeln!(out, "{}", json(&rank::rank(arg, &apps, &history, now())))?,
            Some('a') => writeln!(out, "{}", json(&rank::all(&apps)))?,
            Some('r') => apps = apps::scan(&dirs),
            Some('l') => match apps.iter().find(|a| a.id == arg) {
                Some(app) => {
                    if let Err(e) = launch::spawn(app, &terminal) {
                        eprintln!("launcher: can't start {arg}: {e}");
                        continue;
                    }
                    history.bump(arg, now());
                    history.retain(|id| apps.iter().any(|a| a.id == id));
                    if let Err(e) = history.save() {
                        eprintln!("launcher: can't save history: {e}");
                    }
                }
                None => eprintln!("launcher: no app {arg:?}"),
            },
            _ => eprintln!("launcher: unknown command {line:?}"),
        }
    }
    Ok(())
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs())
}

/// `[[id, name, icon], …]`.
fn json(found: &[&App]) -> String {
    let rows: Vec<String> = found
        .iter()
        .map(|a| {
            format!(
                "[{},{},{}]",
                string(&a.id),
                string(&a.name),
                string(&a.icon)
            )
        })
        .collect();
    format!("[{}]", rows.join(","))
}

