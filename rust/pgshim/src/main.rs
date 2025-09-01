use clap::Parser;
use std::fmt::Debug;
use std::net::SocketAddr;
use std::sync::Arc;

use async_trait::async_trait;
use futures::{stream, Sink};
use pgwire::api::auth::noop::NoopStartupHandler;
use pgwire::api::query::{PlaceholderExtendedQueryHandler, SimpleQueryHandler};
use pgwire::api::results::{DataRowEncoder, FieldFormat, FieldInfo, QueryResponse, Response, Tag};
use pgwire::api::{ClientInfo, MakeHandler, StatelessMakeHandler, Type};
use pgwire::error::{PgWireError, PgWireResult};
use pgwire::messages::PgWireBackendMessage;
use pgwire::tokio::process_socket;
use rusqlite::{Connection, Row};
use tokio::net::TcpListener;

#[derive(Parser, Debug)]
struct Args {
    #[arg(long, default_value = "127.0.0.1:6432")]
    listen: String,
    #[arg(long, default_value = "./data/xda.db")]
    db: String,
}

fn row_text(row: &Row, idx: usize) -> Option<String> {
    row.get::<usize, Option<String>>(idx).unwrap_or(None)
}

struct SqliteHandler {
    db_path: String,
}

#[async_trait]
impl SimpleQueryHandler for SqliteHandler {
    async fn do_query<'a, C>(
        &self,
        _client: &mut C,
        query: &'a str,
    ) -> PgWireResult<Vec<Response<'a>>>
    where
        C: ClientInfo + Sink<PgWireBackendMessage> + Unpin + Send + Sync,
        C::Error: Debug,
        PgWireError: From<<C as Sink<PgWireBackendMessage>>::Error>,
    {
        if query.trim().eq_ignore_ascii_case("SELECT 1") {
            let f = FieldInfo::new("int4".into(), None, None, Type::INT4, FieldFormat::Text);
            let schema = Arc::new(vec![f.clone()]);
            let mut encoder = DataRowEncoder::new(schema.clone());
            encoder.encode_field(&Some(1i32))?;
            let rows = vec![encoder.finish()?];
            let stream = stream::iter(rows.into_iter().map(Ok));
            return Ok(vec![Response::Query(QueryResponse::new(schema, stream))]);
        }
        if query.trim_start().to_uppercase().starts_with("SELECT") {
            let conn =
                Connection::open(&self.db_path).map_err(|e| PgWireError::ApiError(e.into()))?;
            let mut stmt = conn
                .prepare(query)
                .map_err(|e| PgWireError::ApiError(e.into()))?;
            let names: Vec<String> = stmt.column_names().iter().map(|s| s.to_string()).collect();
            let fields: Vec<FieldInfo> = names
                .iter()
                .map(|n| {
                    FieldInfo::new(n.clone().into(), None, None, Type::TEXT, FieldFormat::Text)
                })
                .collect();
            let schema = Arc::new(fields);
            let mut rows_iter = stmt
                .query([])
                .map_err(|e| PgWireError::ApiError(e.into()))?;
            let schema_clone = schema.clone();
            let mut rows_vec = Vec::new();
            while let Some(r) = rows_iter
                .next()
                .map_err(|e| PgWireError::ApiError(e.into()))?
            {
                let mut enc = DataRowEncoder::new(schema_clone.clone());
                for i in 0..names.len() {
                    let v: Option<String> = row_text(r, i);
                    enc.encode_field(&v)?;
                }
                rows_vec.push(enc.finish()?);
            }
            let stream = stream::iter(rows_vec.into_iter().map(Ok));
            return Ok(vec![Response::Query(QueryResponse::new(schema, stream))]);
        }
        Ok(vec![Response::Execution(Tag::new("OK"))])
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    let args = Args::parse();
    let addr: SocketAddr = args.listen.parse()?;
    let listener = TcpListener::bind(addr).await?;
    eprintln!("pgshim listening on {}", addr);

    let auth = Arc::new(StatelessMakeHandler::new(Arc::new(NoopStartupHandler)));
    let processor = Arc::new(StatelessMakeHandler::new(Arc::new(SqliteHandler {
        db_path: args.db,
    })));
    let placeholder = Arc::new(StatelessMakeHandler::new(Arc::new(
        PlaceholderExtendedQueryHandler,
    )));

    loop {
        let (socket, _) = listener.accept().await?;
        let auth_ref = auth.make();
        let proc_ref = processor.make();
        let placeholder_ref = placeholder.make();
        tokio::spawn(async move {
            let _ = process_socket(socket, None, auth_ref, proc_ref, placeholder_ref).await;
        });
    }
}
