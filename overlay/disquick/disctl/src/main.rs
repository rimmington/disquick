extern crate docopt;
extern crate libc;
extern crate regex;
extern crate rustc_serialize;

use regex::Regex;
use std::io;
use std::io::Write;
use std::process::Command;

const USAGE: &'static str = "
Usage:
  disctl [<service>]
  disctl [-e] [-l] [-j | -f] <service>
  disctl (--cat | --cat-script | --cat-pre | --cat-post) <service>
  disctl --clear-failed [<service>]
  disctl (-h | --version)

View and modify local service state.

Options:
  -e --stop         End the service
  -l --start        Launch the service
  -j --journal      Show service journal
  -f --follow       Follow service journal
  --cat             Show service systemd unit file
  --cat-script      Show service script
  --cat-pre         Show service pre-start script
  --cat-post        Show service post-start script
  --clear-failed    Clear failed service(s)
  -h --help         Show this screen
  --version         Show version
";

#[derive(Debug, RustcDecodable, Clone)]
struct Args {
    arg_service: Option<String>,
    flag_stop: bool,
    flag_start: bool,
    flag_journal: bool,
    flag_follow: bool,
    flag_cat: bool,
    flag_cat_script: bool,
    flag_cat_pre: bool,
    flag_cat_post: bool,
    flag_clear_failed: bool,
    flag_version: bool
}

#[derive(Debug)]
enum Error {
    NonZero(Option<i32>),
    NoSuchService,
    UnexpectedOutput(String),
    IoError(io::Error)
}

use Error::*;

impl From<io::Error> for Error {
    fn from(e: io::Error) -> Self { IoError(e) }
}

type Result<T> = std::result::Result<T, Error>;

trait CommandOut : Sized {
    fn run(&mut Command) -> Result<Self>;
}

impl CommandOut for () {
    fn run(cmd: &mut Command) -> Result<Self> {
        let exit = try!(cmd.spawn().and_then(|mut c| c.wait()));
        if exit.success() {
            Ok(())
        } else {
            Err(NonZero(exit.code()))
        }
    }
}

struct Suppress;

impl CommandOut for Suppress {
    fn run(cmd: &mut Command) -> Result<Self> {
        use std::process::Stdio;
        let exit = try!(cmd.stdin(Stdio::null()).stderr(Stdio::null()).stdout(Stdio::null()).spawn().and_then(|mut c| c.wait()));
        if exit.success() {
            Ok(Suppress)
        } else {
            Err(NonZero(exit.code()))
        }
    }
}

#[derive(Debug)]
struct AnyStdout {
    stdout: String,
    status: std::process::ExitStatus
}

impl CommandOut for AnyStdout {
    fn run(cmd: &mut Command) -> Result<Self> {
        use std::process::Stdio;
        use std::io::Read;
        let mut buffer = String::new();
        let mut child = try!(cmd.stderr(Stdio::null()).stdout(Stdio::piped()).spawn());
        let rdres = child.stdout.as_mut().unwrap().read_to_string(&mut buffer);
        let wtres = child.wait();
        let exit = try!(rdres.and(wtres).map_err(IoError));
        Ok(AnyStdout { stdout: buffer, status: exit })
    }
}

impl CommandOut for String {
    fn run(cmd: &mut Command) -> Result<Self> {
        let any : AnyStdout = try!(run(cmd));
        if any.status.success() {
            Ok(any.stdout)
        } else {
            Err(NonZero(any.status.code()))
        }
    }
}

fn run<T>(cmd: &mut Command) -> Result<T> where T : CommandOut {
    T::run(cmd)
}

fn disnix_running() -> Result<bool> {
    match run(Command::new("systemctl").arg("status").arg("disnix.service")) {
        Ok(Suppress) => Ok(true),
        Err(NonZero(Some(code))) if code == 3 => Ok(false),
        Err(e) => Err(e)
    }
}

fn service_full_name(name: String) -> Result<String> {
    if try!(disnix_running()) {
        let out : String = try!(run(Command::new("systemctl").arg("list-units").arg("--no-legend").arg(format!("disnix-*-service-{}.service", name))));
        out.lines()
            .filter_map(|l| {
                let mut words = l.split_whitespace();
                let name = words.next();
                let load = words.next();
                if load == Some("loaded") {
                    name.map(|w| w.to_string())
                } else {
                    None
                }
            }).next().ok_or(UnexpectedOutput(format!("Cannot find service {}", name)))
    } else {
        Ok(name)
    }
}

fn run_with_service(args: &Args, cmd: &mut Command) -> Result<()> {
    run(cmd.arg(args.arg_service.as_ref().expect("command requires service but docopt screwed up")))
}

fn run_with_service_optional(name: Option<&String>, cmd: &mut Command) -> Result<()> {
    if let Some(n) = name {
        cmd.arg(n);
    }
    run(cmd)
}

fn stop(args: &Args) -> Result<bool> {
    if args.flag_stop {
        run_with_service(args, Command::new("sudo").arg("systemctl").arg("stop")).map(|_| true)
    } else {
        Ok(false)
    }
}

fn start(args: &Args) -> Result<bool> {
    if args.flag_start {
        run_with_service(args, Command::new("sudo").arg("systemctl").arg("start")).map(|_| true)
    } else {
        Ok(false)
    }
}

fn journal(args: &Args) -> Result<bool> {
    if args.flag_journal || args.flag_follow {
        run_with_service(args, Command::new("sudo").arg("journalctl").arg(if args.flag_follow { "-fu" } else { "-u" })).map(|_| true)
    } else {
        Ok(false)
    }
}

fn cat(args: &Args) -> Result<bool> {
    if args.flag_cat {
        run_with_service(args, Command::new("systemctl").arg("cat").arg("--no-pager")).map(|_| true)
    } else {
        Ok(false)
    }
}

fn cat_script(args: &Args) -> Result<bool> {
    fn cat_script_property(args: &Args, property: &str) -> Result<bool> {
        let prop_deets : String = try!(run(Command::new("systemctl").arg("show").arg("-p").arg(property).arg(args.arg_service.as_ref().unwrap())));
        if prop_deets == "" {  // May not have this property
            return Ok(true);
        }
        let re = Regex::new(".* argv\\[\\]=(.+?) ;.*").unwrap();
        let captures = try!(re.captures(&prop_deets).ok_or(UnexpectedOutput("bad systemctl show output".to_string())));
        let script : &str = try!((&captures[1]).split_whitespace().last().ok_or(UnexpectedOutput("bad systemctl show output".to_string())));
        println!("{}", tty_coloured(Colour::Blue, format!("# {}", script)));
        run(Command::new("cat").arg(script)).map(|()| true)
    }

    if args.flag_cat_pre {
        cat_script_property(args, "ExecStartPre")
    } else if args.flag_cat_script {
        cat_script_property(args, "ExecStart")
    } else if args.flag_cat_post {
        cat_script_property(args, "ExecStartPost")
    } else {
        Ok(false)
    }
}

fn stdout_is_tty() -> bool {
    unsafe { libc::isatty(libc::STDOUT_FILENO) != 0 }
}

enum Colour {
    Blue,
    Red
}

const ANSI_HIGHLIGHT_BLUE: &'static str = "\x1B[0;1;34m";
const ANSI_HIGHLIGHT_RED: &'static str = "\x1B[38;5;196m";
const ANSI_NORMAL: &'static str = "\x1B[0m";

fn tty_coloured(colour: Colour, msg: String) -> String {
    if stdout_is_tty() {
        let code = match colour {
            Colour::Blue => ANSI_HIGHLIGHT_BLUE,
            Colour::Red  => ANSI_HIGHLIGHT_RED
        };
        format!("{}{}{}", code, msg, ANSI_NORMAL)
    } else {
        msg
    }
}

fn clear_failed(args: &Args) -> Result<bool> {
    if args.flag_clear_failed {
        run_with_service_optional(args.arg_service.as_ref(), Command::new("sudo").arg("systemctl").arg("reset-failed")).map(|_| true)
    } else {
        Ok(false)
    }
}

fn status(name: Option<&String>) -> Result<()> {
    match run_with_service_optional(name, Command::new("systemctl").arg("--no-pager").arg("status")) {
        Err(NonZero(Some(3))) => return Err(NoSuchService),
        Err(e) => return Err(e),
        Ok(_) => {}
    };
    if let None = name {
        let any : AnyStdout = try!(run(Command::new("systemctl").arg("is-system-running")));
        if any.stdout.trim() == "degraded" {
            println!("\nSome units have {}:", tty_coloured(Colour::Red, "failed".to_string()));
            let stdout : String = try!(run(Command::new("systemctl").arg("--failed").env("SYSTEMD_COLORS", if stdout_is_tty() { "1" } else { "0" })));
            let re = Regex::new(r"\d loaded units listed").unwrap();
            print!("{}", match re.split(stdout.as_ref()).next() {
                None => stdout.as_ref(),
                Some(init) => init
            });
        }
    }
    Ok(())
}

const ACTIONS: &'static [fn(&Args) -> Result<bool>] = &[ stop, start, journal, cat, cat_script, clear_failed ];

fn go() -> Result<()> {
    let usage = if std::env::var("MAN") == Ok("1".to_string()) { USAGE.to_string() } else { USAGE.to_string() + "\nSee the man page for more details." };
    let mut args : Args = docopt::Docopt::new(usage).unwrap().version(Some("disctl 1.0".to_string())).decode().unwrap_or_else(|e| e.exit());

    args.arg_service = match args.arg_service {
        Some(s) => try!(service_full_name(s).map(Some)),
        None => None
    };
    let something_ran = try!(ACTIONS.iter().fold(Ok(false), |acc, a| acc.and_then(|acc| a(&args).map(|r| r || acc))));
    if ! something_ran {
        try!(status(args.arg_service.as_ref()));
    }
    Ok(())
}

fn main() {
    std::process::exit(match go() {
        Ok(()) => 0,
        Err(NonZero(_)) => 2,
        Err(NoSuchService) => 3,
        Err(UnexpectedOutput(msg)) => { writeln!(io::stderr(), "{}", msg).unwrap(); 2 } ,
        Err(IoError(err)) => { writeln!(io::stderr(), "{}", err).unwrap(); 2 }
    });
}
