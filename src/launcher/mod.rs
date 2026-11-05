//! launcher (binary `bar-launcher`): the fast half of the app launcher. The UI lives in the bar's Quickshell shell
//! (shell/launcher); it keeps this process running and talks over stdin/stdout.
//!
//! Protocol, one command per stdin line (first char = command):
//! - `q<text>` → one stdout line: `[[id, name, icon], …]`, best match first, max 8.
//!   Empty text → `[]`.
//! - `a` → the same line with every app, A→Z (browsing by scroll).
//! - `r` → rescan the `.desktop` files (the UI sends it on open: new installs show up).
//! - `l<id>` → launch that app detached and count it for ranking.
//!
//! Errors go to stderr; the process only exits when stdin closes.

pub mod apps;
pub mod history;
pub mod launch;
pub mod rank;
pub mod serve;
