// tools/shard-indexer/src/main.rs

mod cli;
mod indexer;

use crate::cli::Cli;
use crate::indexer::run_indexer;

#[tokio::main]
async fn main() {
    let args = Cli::parse();
    if let Err(e) = run_indexer(args).await {
        eprintln!("shard-indexer error: {e}");
        std::process::exit(1);
    }
}
