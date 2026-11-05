//! Installed apps: finds and parses `.desktop` files (XDG desktop entry spec, the
//! `[Desktop Entry]` group only, unlocalized keys).

use std::collections::HashSet;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq)]
pub struct App {
    /// File name without `.desktop`, e.g. `firefox`. Stable key for history.
    pub id: String,
    pub name: String,
    /// Other words that should find it: `GenericName` and `Keywords`.
    pub alt: Vec<String>,
    /// The `Exec` line, field codes (`%U` …) still in.
    pub exec: String,
    /// Icon theme name or absolute path; empty = none.
    pub icon: String,
    pub terminal: bool,
}

/// `applications/` under `$XDG_DATA_HOME` then each `$XDG_DATA_DIRS` entry (spec defaults),
/// then flatpak's export folders if those are missing: a session started from a plain tty
/// login never runs /etc/profile.d/flatpak.sh, so flatpak apps would not show up.
pub fn dirs() -> Vec<PathBuf> {
    let env = |k| std::env::var(k).ok().filter(|v: &String| !v.is_empty());
    let home = env("XDG_DATA_HOME").or_else(|| env("HOME").map(|h| h + "/.local/share"));
    let system = env("XDG_DATA_DIRS").unwrap_or_else(|| "/usr/local/share:/usr/share".into());
    let flatpak = [
        home.as_ref().map(|h| format!("{h}/flatpak/exports/share")),
        Some("/var/lib/flatpak/exports/share".to_string()),
    ];
    let mut out: Vec<String> = home.iter().cloned().collect();
    out.extend(
        system
            .split(':')
            .filter(|d| !d.is_empty())
            .map(String::from),
    );
    for d in flatpak.into_iter().flatten() {
        if !out.contains(&d) {
            out.push(d);
        }
    }
    out.into_iter()
        .map(|d| PathBuf::from(d).join("applications"))
        .collect()
}

/// Every app that wants to be shown. An id found in an earlier dir shadows later ones,
/// also when the earlier entry hides it (that's how users hide system entries).
// shortcut: no subdirectories, OnlyShowIn/NotShowIn or TryExec; add if a stray entry shows up.
pub fn scan(dirs: &[PathBuf]) -> Vec<App> {
    let mut seen = HashSet::new();
    let mut apps = Vec::new();
    for dir in dirs {
        let Ok(entries) = fs::read_dir(dir) else {
            continue;
        };
        for path in entries.flatten().map(|e| e.path()) {
            let Some(id) = path
                .file_name()
                .and_then(|n| n.to_str()?.strip_suffix(".desktop"))
            else {
                continue;
            };
            if !seen.insert(id.to_string()) {
                continue;
            }
            if let Some(app) = fs::read_to_string(&path).ok().and_then(|t| parse(id, &t)) {
                apps.push(app);
            }
        }
    }
    apps
}

/// One entry, or `None` if it's not a visible application.
pub fn parse(id: &str, text: &str) -> Option<App> {
    let mut app = App {
        id: id.into(),
        name: String::new(),
        alt: Vec::new(),
        exec: String::new(),
        icon: String::new(),
        terminal: false,
    };
    let mut is_app = false;
    let mut in_entry = false;
    for line in text.lines().map(str::trim) {
        if line.starts_with('[') {
            in_entry = line == "[Desktop Entry]";
            continue;
        }
        let Some((key, value)) = line
            .split_once('=')
            .filter(|_| in_entry && !line.starts_with('#'))
        else {
            continue;
        };
        let value = value.trim();
        match key.trim() {
            "Type" => is_app = value == "Application",
            "Name" => app.name = value.into(),
            "GenericName" => app.alt.push(value.into()),
            "Keywords" => app
                .alt
                .extend(value.split(';').filter(|k| !k.is_empty()).map(String::from)),
            "Exec" => app.exec = value.into(),
            "Icon" => app.icon = value.into(),
            "Terminal" => app.terminal = value == "true",
            "NoDisplay" | "Hidden" if value == "true" => return None,
            _ => {}
        }
    }
    (is_app && !app.name.is_empty() && !app.exec.is_empty()).then_some(app)
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIREFOX: &str = "[Desktop Entry]\nType=Application\nName=Firefox\nName[de]=Feuerfuchs\n\
        GenericName=Web Browser\nKeywords=internet;www;\nExec=firefox %u\nIcon=firefox\n\n\
        [Desktop Action new-window]\nName=New Window\nExec=firefox --new-window %u\n";

    #[test]
    fn parses_main_group_only() {
        let app = parse("firefox", FIREFOX).unwrap();
        assert_eq!(app.name, "Firefox");
        assert_eq!(app.exec, "firefox %u");
        assert_eq!(app.alt, ["Web Browser", "internet", "www"]);
        assert!(!app.terminal);
    }

    #[test]
    fn skips_hidden_and_non_apps() {
        assert!(parse("x", &FIREFOX.replace("Icon=firefox", "NoDisplay=true")).is_none());
        assert!(parse("x", &FIREFOX.replace("Type=Application", "Type=Link")).is_none());
        assert!(parse("x", "[Desktop Entry]\nType=Application\nName=No exec\n").is_none());
    }
}
