use anyhow::Result;
use clap::Parser;
use pgwire::api::auth::NoAuthentication;
use pgwire::api::portal::{Portal, PortalStore};
use pgwire::api::{results::{FieldInfo,QueryResponse}, CopyFormat, MakeTlsConnector};
use pgwire::api::stmt::{NoopQueryParser, Statement};
use pgwire::tokio::process_socket;
use rusqlite::{Connection, Row};
use std::net::SocketAddr;
use tokio::net::TcpListener;

#[derive(Parser, Debug)]
struct Args {
    #[arg(long, default_value="127.0.0.1:6432")]
    listen: String,
    #[arg(long, default_value="./data/xda.db")]
    db: String,
}

fn row_to_text(row: &Row, idx: usize) -> String {
    match row.get::<usize, String>(idx) { Ok(v)=>v, Err(_)=>"<null>".to_string() }
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    let args = Args::parse();
    let addr: SocketAddr = args.listen.parse()?;
    let listener = TcpListener::bind(addr).await?;
    eprintln!("pgshim listening on {}", addr);

    loop {
        let (socket, _peer) = listener.accept().await?;
        let db_path = args.db.clone();
        tokio::spawn(async move {
            let auth = NoAuthentication::new();
            let portal_store = PortalStore::new();
            let parser = NoopQueryParser::new(); // we operate on raw SQL strings
            let tls = MakeTlsConnector::none();
            let handler = move |query: &str| -> Result<QueryResponse> {
                // Very small SQL router:
                if query.trim().eq_ignore_ascii_case("SELECT 1") {
                    let fields = vec![FieldInfo::new("int4".into(), 23, 4, None, None)];
                    let rows = vec![vec!["1".into()]];
                    return Ok(QueryResponse::Simple { fields, rows });
                }
                // Passthrough to SQLite for a limited subset
                let conn = Connection::open(&db_path)?;
                if query.trim_start().to_uppercase().starts_with("SELECT") {
                    let mut stmt = conn.prepare(query)?;
                    let col_names: Vec<String> = stmt.column_names().into_iter().map(|s| s.to_string()).collect();
                    let mut rows_iter = stmt.query([])?;
                    let mut out_rows = Vec::new();
                    while let Some(row) = rows_iter.next()? {
                        let mut out = Vec::new();
                        for i in 0..col_names.len() {
                            out.push(row_to_text(row, i));
                        }
                        out_rows.push(out);
                    }
                    let fields = col_names.into_iter().map(|n| FieldInfo::new(n.into(), 25, 0, None, None)).collect();
                    return Ok(QueryResponse::Simple { fields, rows: out_rows });
                }
                // default: OK empty
                Ok(QueryResponse::Empty)
            };

            if let Err(e) = process_socket(socket, auth, parser, portal_store, tls, handler).await {
                eprintln!("session error: {}", e);
            }
        });
    }
}
