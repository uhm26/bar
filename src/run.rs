//! The main loop: one report per interval on stdout, commands on stdin.
//!
//! stdin commands, one per line: `procs on|off` (process list) and `net on|off` (per-app
//! network). They are most of the work (~290 processes × 3 files, or one `ss` run, every
//! second), so the bar turns them on only while a drawer shows them. `on` answers after a
//! short warm-up instead of the next full interval.

use std::io::{BufRead, Write};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::thread;
use std::time::Duration;

use crate::json;
use crate::sampler::{Error, Sampler};

const INTERVAL: Duration = Duration::from_secs(1);
/// Rates need two snapshots: the gap between them after an `on`.
const WARMUP: Duration = Duration::from_millis(200);

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Command {
    Procs(bool),
    Net(bool),
}

pub fn run() -> Result<(), Error> {
    let mut sampler = Sampler::new()?;
    let commands = listen();
    let mut wait = INTERVAL;
    loop {
        match commands.recv_timeout(wait) {
            Ok(cmd) => {
                let warm = match cmd {
                    Command::Procs(on) => sampler.set_procs(on)?,
                    Command::Net(on) => sampler.set_net(on),
                };
                // Warm-up only when a list just turned on: repeats don't print extra reports.
                wait = if warm { WARMUP } else { INTERVAL };
                continue;
            }
            Err(RecvTimeoutError::Timeout) => {}
            // stdin closed (e.g. `bar-sys < /dev/null`): plain timer from here on.
            Err(RecvTimeoutError::Disconnected) => thread::sleep(wait),
        }
        wait = INTERVAL;
        let line = json::render(&sampler.sample()?);
        // The bar closed our stdout: it is gone, so are we.
        // Lock per line: the visualizer thread writes lines too.
        let mut out = std::io::stdout().lock();
        if writeln!(out, "{line}").and_then(|()| out.flush()).is_err() {
            return Ok(());
        }
    }
}

/// Reads stdin on its own thread; each known command becomes a message.
fn listen() -> Receiver<Command> {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        for line in std::io::stdin().lock().lines() {
            let Ok(line) = line else { break };
            let Some(cmd) = command(&line) else { continue };
            if tx.send(cmd).is_err() {
                break;
            }
        }
    });
    rx
}

/// `procs on`, `net off`, ... → Command; anything else → None.
pub fn command(line: &str) -> Option<Command> {
    let (what, state) = line.trim().split_once(' ')?;
    let on = match state {
        "on" => true,
        "off" => false,
        _ => return None,
    };
    match what {
        "procs" => Some(Command::Procs(on)),
        "net" => Some(Command::Net(on)),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::{Command, command};

    #[test]
    fn known_commands_only() {
        assert_eq!(command("procs on\n"), Some(Command::Procs(true)));
        assert_eq!(command(" net off "), Some(Command::Net(false)));
        assert_eq!(command("procs"), None);
        assert_eq!(command("disk on"), None);
    }
}
