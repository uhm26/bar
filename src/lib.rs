//! `bar` crate: the bar's Rust helpers. Binary `bar-sys` (system stats, modules below) and
//! binary `bar-launcher` (app launcher helper, module `launcher`, src/bin/launcher.rs).
//!
//! `bar-sys`: system stats for the Quickshell bar (`shell/sys/Sys.qml`).
//!
//! Once a second it prints one JSON line on stdout:
//! `{"cpu":12.3,"temp":45.1,"up":3600,"net":[down,up,rx,tx],"mem":[used,total],"swap":[used,total],"procs":[[name,cpu,mem,[pid,...]],...],"apps":[[name,down,up],...]}`
//! cpu and process cpu are % of the whole machine, memory in bytes, temp in °C or null, up = seconds since boot or null,
//! net = bytes/s received and sent, then bytes since boot (null on the first report).
//! stdin takes `procs on|off` and `net on|off` (see run.rs); off = that list is null.
//! apps = per-app TCP bytes/s (sockets.rs); UDP is not split per app.
//! Processes are grouped by program name (exe, see procs::pick_name); the list holds the top ones by cpu and by memory.

pub mod cpu;
pub mod json;
pub mod launcher;
pub mod mem;
pub mod net;
pub mod procs;
pub mod run;
pub mod sampler;
pub mod sockets;
pub mod temp;
pub mod uptime;
