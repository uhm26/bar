use std::process::ExitCode;

fn main() -> ExitCode {
    match bar::launcher::serve::run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("launcher: {e}");
            ExitCode::FAILURE
        }
    }
}
