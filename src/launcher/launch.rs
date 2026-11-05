//! Starting an app fully detached: its own process group, no stdio, not our child.

use std::io;
use std::os::unix::process::CommandExt;
use std::process::{Command, Stdio};

use super::apps::App;

/// The `Exec` line with its field codes dropped (we never pass files or URLs), `%%` → `%`.
pub fn command_line(exec: &str) -> String {
    let mut out = String::with_capacity(exec.len());
    let mut chars = exec.chars();
    while let Some(c) = chars.next() {
        match c {
            '%' => {
                if chars.next() == Some('%') {
                    out.push('%');
                }
            }
            c => out.push(c),
        }
    }
    out.trim().to_string()
}

/// Runs the app (in `terminal -e` if it wants one). A throwaway `sh` backgrounds it and
/// exits at once, so the app is re-parented to init and never becomes our zombie.
// shortcut: Exec goes through `sh -c`, fine for spec-quoted lines; a strict Exec parser if one breaks.
pub fn spawn(app: &App, terminal: &str) -> io::Result<()> {
    let line = command_line(&app.exec);
    let mut argv = vec!["sh", "-c", line.as_str()];
    if app.terminal {
        // $TERMINAL may carry its own arguments ("foot --app-id x"): one word each.
        argv.splice(0..0, terminal.split_whitespace().chain(["-e"]));
    }
    let status = Command::new("sh")
        .args(["-c", "\"$@\" &", "sh"])
        .args(&argv)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .env_remove("QSG_USE_SIMPLE_ANIMATION_DRIVER") // the bar's Qt pragma, not meant for apps
        .status()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::other(format!("sh exited with {status}")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn drops_field_codes() {
        assert_eq!(command_line("firefox %u"), "firefox");
        assert_eq!(command_line("code --new %F --x"), "code --new  --x");
        assert_eq!(command_line("printf 100%%"), "printf 100%");
    }
}
