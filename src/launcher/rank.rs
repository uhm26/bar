//! Fuzzy matching and ranking: the query's letters must appear in order in the name;
//! starts of words, runs of letters and recent use rank higher.

use super::apps::App;
use super::history::History;

/// Rows the UI shows.
pub const LIMIT: usize = 8;

/// Every app, A→Z ignoring case (browsing: no ranking, no limit).
pub fn all(apps: &[App]) -> Vec<&App> {
    let mut list: Vec<&App> = apps.iter().collect();
    list.sort_by_cached_key(|a| a.name.to_lowercase());
    list
}

/// Best apps for `query`, best first. Ties: shorter name, then alphabetical.
pub fn rank<'a>(query: &str, apps: &'a [App], history: &History, now: u64) -> Vec<&'a App> {
    let q = query_chars(query); // once, not per app and alt word
    let mut hits: Vec<(i32, &App)> = apps
        .iter()
        .filter_map(|a| {
            let alt = a
                .alt
                .iter()
                .filter_map(|w| score_chars(&q, w))
                .max()
                .map(|s| s - 20);
            let best = score_chars(&q, &a.name).max(alt)?;
            Some((best + history.boost(&a.id, now), a))
        })
        .collect();
    hits.sort_by(|(sa, a), (sb, b)| {
        sb.cmp(sa)
            .then(a.name.len().cmp(&b.name.len()))
            .then(a.name.cmp(&b.name))
    });
    hits.into_iter().take(LIMIT).map(|(_, a)| a).collect()
}

/// Score of `query` (spaces ignored, any case) in `text`, `None` if it doesn't match.
/// Tries every start of the first letter and keeps the best greedy match from there.
pub fn score(query: &str, text: &str) -> Option<i32> {
    score_chars(&query_chars(query), text)
}

/// The query as lowercase chars, spaces dropped: made once per ranking.
fn query_chars(query: &str) -> Vec<char> {
    query.chars().filter(|c| !c.is_whitespace()).flat_map(char::to_lowercase).collect()
}

fn score_chars(q: &[char], text: &str) -> Option<i32> {
    let t: Vec<char> = text.chars().collect();
    let lower: Vec<char> = t
        .iter()
        .map(|c| c.to_lowercase().next().unwrap_or(*c))
        .collect();
    let first = *q.first()?;
    (0..t.len())
        .filter(|&i| lower[i] == first)
        .filter_map(|start| greedy(q, &t, &lower, start))
        .max()
}

/// Matches `q` left to right starting at `start`. Per letter: +10, word start +20 (+10
/// more at the very start), right after the previous letter +15, a gap −1 per skipped char.
fn greedy(q: &[char], t: &[char], lower: &[char], start: usize) -> Option<i32> {
    let mut score = -(start.min(15) as i32);
    let mut prev: Option<usize> = None;
    let mut i = start;
    for &c in q {
        while *lower.get(i)? != c {
            i += 1;
        }
        score += 10;
        let word_start = i == 0
            || !t[i - 1].is_alphanumeric()
            || (t[i].is_uppercase() && t[i - 1].is_lowercase());
        if word_start {
            score += if i == 0 { 30 } else { 20 };
        }
        match prev {
            Some(p) if p + 1 == i => score += 15,
            Some(p) => score -= (i - p - 1).min(10) as i32,
            None => {}
        }
        prev = Some(i);
        i += 1;
    }
    Some(score)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::launcher::apps::App;

    fn app(id: &str, name: &str) -> App {
        App {
            id: id.into(),
            name: name.into(),
            alt: Vec::new(),
            exec: id.into(),
            icon: String::new(),
            terminal: false,
        }
    }

    #[test]
    fn matches_in_order_any_case() {
        assert!(score("ff", "Firefox").is_some());
        assert!(score("FOX", "firefox").is_some());
        assert!(score("xf", "Firefox").is_none());
        assert!(score("", "Firefox").is_none());
    }

    #[test]
    fn prefix_and_word_starts_win() {
        assert!(score("fi", "Files") > score("fi", "Profile"));
        assert!(score("vsc", "Visual Studio Code") > score("vsc", "Avsc thing"));
        assert!(score("term", "term") > score("term", "xterm"));
    }

    #[test]
    fn history_lifts_a_used_app() {
        let apps = [app("files", "Files"), app("firefox", "Firefox")];
        let none = History::default();
        assert_eq!(rank("f", &apps, &none, 0)[0].id, "files"); // shorter name wins the tie
        let mut used = History::default();
        used.bump("firefox", 0);
        assert_eq!(rank("f", &apps, &used, 0)[0].id, "firefox");
    }

    #[test]
    fn all_is_alphabetical_ignoring_case() {
        let apps = [app("b", "beta"), app("a", "Alpha"), app("c", "Gamma")];
        let names: Vec<_> = all(&apps).iter().map(|a| a.name.as_str()).collect();
        assert_eq!(names, ["Alpha", "beta", "Gamma"]);
    }

    #[test]
    fn keywords_find_it_below_name_matches() {
        let mut ff = app("firefox", "Firefox");
        ff.alt = vec!["Web Browser".into()];
        let apps = [ff, app("webcam", "Webcam")];
        let hits = rank("web", &apps, &History::default(), 0);
        assert_eq!(
            hits.iter().map(|a| a.id.as_str()).collect::<Vec<_>>(),
            ["webcam", "firefox"]
        );
    }
}
