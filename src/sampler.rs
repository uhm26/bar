//! One report per call: deltas against the previous call.

use std::collections::{HashMap, HashSet};
use std::fmt;
use std::path::PathBuf;
use std::time::Instant;

use crate::{cpu, mem, net, procs, sockets, temp, uptime};

/// How many process groups by cpu and by memory each report keeps.
const TOP: usize = 15;

pub struct Report {
    pub cpu: f64,
    pub temp: Option<f64>,
    pub up: Option<u64>,
    /// Bytes/s (down, up) since the previous report plus the byte counters since boot;
    /// None if /proc/net/dev is unreadable.
    pub net: Option<(f64, f64, net::Bytes)>,
    /// Per-app TCP (name, down, up) bytes/s, busiest first; None with `net off` (JSON null,
    /// so the bar keeps its last list instead of flashing an empty one).
    pub apps: Option<Vec<(String, f64, f64)>>,
    pub mem: mem::Mem,
    /// None with `procs off` (JSON null, see `apps`).
    pub procs: Option<Vec<procs::Group>>,
}

#[derive(Debug)]
pub enum Error {
    Cpu(cpu::Error),
    Mem(mem::Error),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Error::Cpu(e) => e.fmt(f),
            Error::Mem(e) => e.fmt(f),
        }
    }
}

/// Process ticks by pid plus the machine's cpu times read at the same moment, so process
/// shares are measured over exactly the time between two snapshots.
type Snapshot = (HashMap<u32, u64>, cpu::Times);

pub struct Sampler {
    cpu: cpu::Times,
    /// None = process list off (`procs off`): no /proc/<pid> scans at all.
    procs: Option<Snapshot>,
    temp: Option<PathBuf>,
    /// Our parent chain: never sent as killable pids (procs::session_chain).
    session: HashSet<u32>,
    /// Last network byte counters and when they were read (intervals vary: warm-up).
    net: Option<(net::Bytes, Instant)>,
    /// Socket counters and when they were read; None = per-app network off (`net off`).
    sockets: Option<(sockets::Counters, Instant)>,
}

impl Sampler {
    /// Starts with both lists on, so `bar-sys` alone prints everything and the bar has
    /// lists to show before its first drawer opens.
    pub fn new() -> Result<Self, Error> {
        Ok(Sampler {
            cpu: cpu::read().map_err(Error::Cpu)?,
            procs: Some(snapshot()?),
            temp: temp::find(),
            session: procs::session_chain(),
            net: net::read().map(|b| (b, Instant::now())),
            // One scan at start, so the bar has lists before any drawer opens (it turns
            // them off after the first report).
            sockets: Some((sockets::counters(&sockets::read()), Instant::now())),
        })
    }

    /// True if the list just turned on (the loop then takes a quick warm-up sample).
    pub fn set_procs(&mut self, on: bool) -> Result<bool, Error> {
        match (on, self.procs.is_some()) {
            (true, false) => {
                // Hyprland may have (re)started since bar-sys did: refresh the protected pids.
                self.session = procs::session_chain();
                self.procs = Some(snapshot()?);
                Ok(true)
            }
            (false, _) => {
                self.procs = None;
                Ok(false)
            }
            (true, true) => Ok(false),
        }
    }

    /// Rate since the last call, then remember this read for the next one.
    fn net_rate(&mut self) -> Option<(f64, f64, net::Bytes)> {
        let now = (net::read()?, Instant::now());
        let rate = self.net.map(|(bytes, at)| {
            let (down, up) = net::rate(bytes, now.0, now.1.duration_since(at).as_secs_f64());
            (down, up, now.0)
        });
        self.net = Some(now);
        rate
    }

    /// True if per-app network just turned on. A running one keeps its baseline.
    pub fn set_net(&mut self, on: bool) -> bool {
        let starting = on && self.sockets.is_none();
        if starting {
            self.sockets = Some((sockets::counters(&sockets::read()), Instant::now()));
        } else if !on {
            self.sockets = None;
        }
        starting
    }

    /// Per-app rates since the last call (only while `net on`).
    fn app_rates(&mut self) -> Option<Vec<(String, f64, f64)>> {
        let (prev, at) = self.sockets.take()?;
        let now = sockets::read();
        let read_at = Instant::now(); // the counters' moment, not after the name lookups
        let list = sockets::apps(&prev, &now, read_at.duration_since(at).as_secs_f64());
        self.sockets = Some((sockets::counters(&now), read_at));
        Some(list)
    }

    pub fn sample(&mut self) -> Result<Report, Error> {
        let now = cpu::read().map_err(Error::Cpu)?;
        let mem = mem::read().map_err(Error::Mem)?;
        let list = match self.procs.take() {
            Some((ticks, base)) => {
                let samples = procs::read_all();
                let total = now.total.saturating_sub(base.total);
                let groups = procs::group(&ticks, &samples, total, &self.session);
                self.procs = Some((procs::ticks(&samples), now));
                Some(procs::top(groups, TOP))
            }
            None => None,
        };
        let report = Report {
            cpu: cpu::usage(&self.cpu, &now),
            temp: self.temp.as_deref().and_then(temp::read),
            up: uptime::read(),
            net: self.net_rate(),
            apps: self.app_rates(),
            mem,
            procs: list,
        };
        self.cpu = now;
        Ok(report)
    }
}

/// Cpu times first, then the scan: the same order as `sample`, so the warm-up delta after
/// `procs on` covers the same span for the machine and for the processes.
fn snapshot() -> Result<Snapshot, Error> {
    let base = cpu::read().map_err(Error::Cpu)?;
    Ok((procs::ticks(&procs::read_all()), base))
}
