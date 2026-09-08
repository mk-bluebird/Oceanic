use serde::Serialize;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, ExitCode};

const DID_ANCHOR: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Debug, Serialize)]
struct ProofResult {
    harness: &'static str,
    status: &'static str,
}

#[derive(Debug, Serialize)]
struct ProofReport {
    schema_version: &'static str,
    crate_name: &'static str,
    did_anchor: &'static str,
    verification_command: Vec<String>,
    passed: bool,
    proofs: Vec<ProofResult>,
}

fn main() -> ExitCode {
    let output_path = match env::args().nth(1) {
        Some(value) => PathBuf::from(value),
        None => {
            eprintln!("usage: cargo run -p kersafety-prover --bin kersafety-report -- <output.json>");
            return ExitCode::from(64);
        }
    };

    let command = [
        "kani".to_owned(),
        "--package".to_owned(),
        "kersafety-prover".to_owned(),
        "--harnesses".to_owned(),
        "score_never_exceeds_scale,evidence_is_monotone,risk_is_antitone,evidence_input_saturates,risk_input_saturates,favorable_composition_is_monotone".to_owned(),
    ];

    let status = Command::new("cargo")
        .args(&command)
        .status()
        .expect("failed to run `cargo kani`; install and configure Kani first");

    let harnesses = [
        "score_never_exceeds_scale",
        "evidence_is_monotone",
        "risk_is_antitone",
        "evidence_input_saturates",
        "risk_input_saturates",
        "favorable_composition_is_monotone",
    ];

    let report = ProofReport {
        schema_version: "1.0",
        crate_name: "kersafety-prover",
        did_anchor: DID_ANCHOR,
        verification_command: std::iter::once("cargo".to_owned())
            .chain(command)
            .collect(),
        passed: status.success(),
        proofs: harnesses
            .into_iter()
            .map(|harness| ProofResult {
                harness,
                status: if status.success() { "passed" } else { "not-passed" },
            })
            .collect(),
    };

    let encoded = match serde_json::to_vec_pretty(&report) {
        Ok(value) => value,
        Err(error) => {
            eprintln!("could not serialize report: {error}");
            return ExitCode::from(70);
        }
    };

    if let Some(parent) = output_path.parent() {
        if let Err(error) = fs::create_dir_all(parent) {
            eprintln!("could not create report directory: {error}");
            return ExitCode::from(73);
        }
    }

    if let Err(error) = fs::write(&output_path, encoded) {
        eprintln!("could not write report: {error}");
        return ExitCode::from(73);
    }

    if status.success() {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}
