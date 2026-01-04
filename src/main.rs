use axum::{
    extract::Path,
    http::{HeaderMap, Method, StatusCode},
    routing::{any, get},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{fs, time::Duration, collections::HashMap};
use chrono::{Utc, Duration as ChronoDuration};
use uuid::Uuid;
use jemallocator::Jemalloc;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;

#[derive(Serialize, Deserialize)]
struct RequestLog {
    timestamp: String,
    method: String,
    headers: HashMap<String, String>,
    body: serde_json::Value,
}

#[derive(Serialize, Deserialize)]
struct CustomResponse {
    status: u16,
    body: serde_json::Value,
}

#[tokio::main]
async fn main() {
    // Memastikan folder data ada untuk penyimpanan JSON
    fs::create_dir_all("data").expect("Gagal membuat folder data");

    // Background Task: Pembersihan otomatis file > 24 jam
    tokio::spawn(async {
        loop {
            cleanup_old_files("data", 24).await;
            tokio::time::sleep(Duration::from_secs(3600)).await;
        }
    });

    let app = Router::new()
        .route("/bin/:id", any(capture_handler))
        .route("/create", get(create_bin));

    let addr = "0.0.0.0:9997";
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    println!("🚀 Request Bin aktif di http://{}", addr);
    
    axum::serve(listener, app).await.unwrap();
}

async fn create_bin() -> String {
    let id = Uuid::new_v4().to_string();
    let path = format!("data/{}", id);
    fs::create_dir_all(&path).unwrap();
    
    let default_res = CustomResponse {
        status: 200,
        body: serde_json::json!({"status": "captured_by_rust", "bin_id": id}),
    };
    fs::write(format!("{}/response.json", path), serde_json::to_string(&default_res).unwrap()).unwrap();

    format!("Bin ID: {}\nURL: /bin/{}", id, id)
}

async fn capture_handler(
    Path(id): Path<String>,
    method: Method,
    headers: HeaderMap,
    body: String,
) -> (StatusCode, Json<serde_json::Value>) {
    let bin_path = format!("data/{}", id);
    
    if !std::path::Path::new(&bin_path).exists() {
        return (StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "Bin not found"})));
    }

    let header_map: HashMap<String, String> = headers
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_str().unwrap_or("").to_string()))
        .collect();

    let log = RequestLog {
        timestamp: Utc::now().to_rfc3339(),
        method: method.to_string(),
        headers: header_map,
        body: serde_json::from_str(&body).unwrap_or(serde_json::json!(body)),
    };

    let filename = format!("{}/{}.json", bin_path, Utc::now().timestamp_millis());
    let _ = fs::write(filename, serde_json::to_string_pretty(&log).unwrap());

    let config_path = format!("{}/response.json", bin_path);
    if let Ok(config_str) = fs::read_to_string(config_path) {
        if let Ok(custom) = serde_json::from_str::<CustomResponse>(&config_str) {
            let status = StatusCode::from_u16(custom.status).unwrap_or(StatusCode::OK);
            return (status, Json(custom.body));
        }
    }

    (StatusCode::OK, Json(serde_json::json!({"status": "captured"})))
}

async fn cleanup_old_files(dir: &str, hours: i64) {
    let now = Utc::now();
    for entry in walkdir::WalkDir::new(dir).into_iter().filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            if let Ok(metadata) = entry.metadata() {
                if let Ok(modified) = metadata.modified() {
                    let modified_chrono: chrono::DateTime<Utc> = modified.into();
                    if now - modified_chrono > ChronoDuration::hours(hours) {
                        let _ = fs::remove_file(entry.path());
                    }
                }
            }
        }
    }
}