use std::process::ExitCode;

fn main() -> ExitCode {
    match bar::run::run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("bar-sys: {e}");
            ExitCode::FAILURE
        }
    }
}
