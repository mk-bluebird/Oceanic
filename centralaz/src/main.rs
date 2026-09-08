mod evidence_integrity;

use crate::evidence_integrity::verify_csv_evidence;
use std::path::PathBuf;
use std::process::ExitCode;

struct InputShard {
    csv_path: PathBuf,
    evidencehex: Option<String>,
}

fn process_shard(input: InputShard) -> Result<(), Box<dyn std::error::Error>> {
    let verified = verify_csv_evidence(&input.csv_path, input.evidencehex.as_deref())?;

    let csv_reader = std::fs::File::open(&input.csv_path)?;
    let parsed_rows = parse_csv_only_after_integrity_gate(csv_reader)?;

    emit_ceim_result(parsed_rows, &verified.sha256_hex, verified.byte_len)?;
    Ok(())
}

fn parse_csv_only_after_integrity_gate(
    reader: std::fs::File,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    use std::io::{BufRead, BufReader};

    let buffered = BufReader::new(reader);
    let rows = buffered.lines().collect::<Result<Vec<_>, _>>()?;

    if rows.is_empty() {
        return Err("CSV shard is empty".into());
    }

    Ok(rows)
}

fn emit_ceim_result(
    _rows: Vec<String>,
    _verified_evidencehex: &str,
    _verified_byte_len: u64,
) -> Result<(), Box<dyn std::error::Error>> {
    Ok(())
}

fn main() -> ExitCode {
    let mut args = std::env::args_os().skip(1);

    let Some(csv_path) = args.next() else {
        eprintln!("usage: centralaz <shard.csv> <evidencehex>");
        return ExitCode::from(64);
    };

    let evidencehex = args.next().and_then(|value| value.into_string().ok());

    if args.next().is_some() {
        eprintln!("usage: centralaz <shard.csv> <evidencehex>");
        return ExitCode::from(64);
    }

    match process_shard(InputShard {
        csv_path: PathBuf::from(csv_path),
        evidencehex,
    }) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("centralaz rejected input: {error}");
            ExitCode::from(65)
        }
    }
}
