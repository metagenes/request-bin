use axum::{
    extract::Path,
    http::{HeaderMap, Method, StatusCode},
    routing::{any, get, put},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{fs, time::Duration, collections::HashMap};
use chrono::{Utc, Duration as ChronoDuration};
use uuid::Uuid;
use jemallocator::Jemalloc;
use tower_http::cors::CorsLayer;
use tower_http::services::ServeDir;

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

#[derive(Serialize)]
struct BinInfo {
    id: String,
    url: String,
    created: String,
}

#[derive(Serialize)]
struct BinDetail {
    id: String,
    url: String,
    response: CustomResponse,
    recent_logs: Vec<RequestLog>,
}

#[derive(Deserialize)]
struct UpdateResponse {
    status: u16,
    body: serde_json::Value,
}

#[tokio::main]
async fn main() {
    // Memastikan folder data dan static ada
    fs::create_dir_all("data").expect("Gagal membuat folder data");
    fs::create_dir_all("static").expect("Gagal membuat folder static");

    // Background Task: Pembersihan otomatis file > 2 jam
    tokio::spawn(async {
        loop {
            cleanup_old_files("data", 2).await;
            tokio::time::sleep(Duration::from_secs(3600)).await;
        }
    });

    let app = Router::new()
        .route("/bin/:id", any(capture_handler))
        .route("/create", get(create_bin))
        .route("/api/bins", get(list_bins))
        .route("/api/bins/:id", get(get_bin_detail))
        .route("/api/bins/:id/response", put(update_bin_response))
        .nest_service("/", ServeDir::new("static"))
        .layer(CorsLayer::permissive());

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

async fn list_bins() -> Json<Vec<BinInfo>> {
    let mut bins = Vec::new();
    
    if let Ok(entries) = fs::read_dir("data") {
        for entry in entries.filter_map(|e| e.ok()) {
            if entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                let id = entry.file_name().to_string_lossy().to_string();
                let created = entry.metadata()
                    .and_then(|m| m.created())
                    .map(|t| {
                        let dt: chrono::DateTime<Utc> = t.into();
                        dt.to_rfc3339()
                    })
                    .unwrap_or_else(|_| "unknown".to_string());
                
                bins.push(BinInfo {
                    id: id.clone(),
                    url: format!("/bin/{}", id),
                    created,
                });
            }
        }
    }
    
    Json(bins)
}

async fn get_bin_detail(Path(id): Path<String>) -> Result<Json<BinDetail>, StatusCode> {
    let bin_path = format!("data/{}", id);
    
    if !std::path::Path::new(&bin_path).exists() {
        return Err(StatusCode::NOT_FOUND);
    }
    
    // Read response config
    let config_path = format!("{}/response.json", bin_path);
    let response = if let Ok(config_str) = fs::read_to_string(&config_path) {
        serde_json::from_str::<CustomResponse>(&config_str).unwrap_or(CustomResponse {
            status: 200,
            body: serde_json::json!({"status": "ok"}),
        })
    } else {
        CustomResponse {
            status: 200,
            body: serde_json::json!({"status": "ok"}),
        }
    };
    
    // Read recent logs (last 10)
    let mut logs = Vec::new();
    if let Ok(entries) = fs::read_dir(&bin_path) {
        let mut log_files: Vec<_> = entries
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name().to_string_lossy().ends_with(".json") 
                && e.file_name().to_string_lossy() != "response.json"
            })
            .collect();
        
        log_files.sort_by_key(|entry| {
            std::cmp::Reverse(
                entry.metadata()
                    .and_then(|m| m.modified())
                    .ok()
            )
        });
        
        for entry in log_files.iter().take(10) {
            if let Ok(content) = fs::read_to_string(entry.path()) {
                if let Ok(log) = serde_json::from_str::<RequestLog>(&content) {
                    logs.push(log);
                }
            }
        }
    }
    
    Ok(Json(BinDetail {
        id: id.clone(),
        url: format!("/bin/{}", id),
        response,
        recent_logs: logs,
    }))
}

async fn update_bin_response(
    Path(id): Path<String>,
    Json(update): Json<UpdateResponse>,
) -> Result<StatusCode, StatusCode> {
    let bin_path = format!("data/{}", id);
    
    if !std::path::Path::new(&bin_path).exists() {
        return Err(StatusCode::NOT_FOUND);
    }
    
    let custom_response = CustomResponse {
        status: update.status,
        body: update.body,
    };
    
    let config_path = format!("{}/response.json", bin_path);
    fs::write(config_path, serde_json::to_string(&custom_response).unwrap())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(StatusCode::OK)
}

async fn cleanup_old_files(dir: &str, hours: i64) {
    let now = Utc::now();
    // 1. Bersihkan file lama
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

    // 2. Hapus folder bin yang kosong
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.filter_map(|e| e.ok()) {
            if entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                // remove_dir hanya berhasil jika folder kosong
                let _ = fs::remove_dir(entry.path());
            }
        }
    }
}
