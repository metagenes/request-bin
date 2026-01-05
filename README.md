# Rust Request Bin 🦀

A simple Request Bin written in Rust using the Axum web framework. This application allows you to capture and log all HTTP requests for debugging, webhook testing, or monitoring API calls.

## 🌟 Features

- **Web UI Management**: Modern web interface to manage bins and responses without code editor
- **Capture HTTP Requests**: Captures all types of HTTP requests (GET, POST, PUT, DELETE, etc.)
- **JSON Storage**: Stores each request in an easy-to-read JSON format
- **Custom Response**: Configure response status code and body for each bin via UI
- **GitHub Actions CI/CD**: Build on GitHub runners, deploy to local server
- **Auto Cleanup**: Automatically removes files older than 24 hours
- **Memory Efficient**: Uses jemalloc for memory optimization, suitable for Mini PCs
- **Lightweight & Fast**: High performance with low memory footprint

## 🚀 Quick Start

### Prerequisites

- Rust 1.70+ (Edition 2024)
- Cargo

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd rust-request-bin
```

2. Build the project:
```bash
cargo build --release
```

3. Run the application:
```bash
cargo run --release
```

The server will run at `http://0.0.0.0:9997`

## 🎨 Web UI

Access the modern web interface at `http://localhost:9997` to:

- **View All Bins**: See all your request bins in a beautiful card grid
- **Create New Bins**: One-click bin creation
- **Edit Responses**: Visual JSON editor with validation
- **View Request Logs**: See recent requests captured by each bin
- **Copy URLs**: Easy copy-to-clipboard for bin URLs

### Features:
- 🎨 Modern glassmorphism design with dark mode
- ✨ Smooth animations and micro-interactions
- 📱 Fully responsive layout
- ✅ Real-time JSON validation
- 🔄 Auto-refresh every 30 seconds

## 🚢 Deployment

### Local Build & Deploy

For local compilation and deployment:

```bash
./update.sh
```

This will:
1. Build the project locally with `cargo build --release`
2. Strip the binary
3. Restart the systemd service
4. Show service status

### GitHub Actions Build & Deploy

For remote building (saves CPU/RAM on your Mini PC):

```bash
./update-github.sh
```

This will:
1. Commit and push changes to GitHub
2. Trigger GitHub Actions workflow
3. Wait for build to complete on GitHub runners
4. Download the compiled binary
5. Deploy and restart the service

**Benefits:**
- ✅ No local compilation needed
- ✅ Faster builds on GitHub infrastructure
- ✅ Automatic artifact retention
- ✅ Easy rollback capability

**Setup GitHub Actions:**

1. Push your code to GitHub:
```bash
git remote add origin https://github.com/YOUR_USERNAME/rust-request-bin.git
git push -u origin main
```

2. Install GitHub CLI (optional, for automatic workflow monitoring):
```bash
sudo apt install gh
gh auth login
```

3. Use the deployment script:
```bash
./update-github.sh "Your commit message"
```

Without GitHub CLI, the script will guide you to manually download the artifact.

## 📖 Usage

### 1. Create a New Bin

```bash
curl http://localhost:9997/create
```

Response:
```
Bin ID: c5f64cbb-7962-4091-a004-24adfde479a8
URL: /bin/c5f64cbb-7962-4091-a004-24adfde479a8
```

### 2. Send Requests to Your Bin

Send requests with any method to your bin URL:

```bash
# GET Request
curl http://localhost:9997/bin/c5f64cbb-7962-4091-a004-24adfde479a8

# POST Request with JSON
curl -X POST http://localhost:9997/bin/c5f64cbb-7962-4091-a004-24adfde479a8 \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# PUT Request with custom headers
curl -X PUT http://localhost:9997/bin/c5f64cbb-7962-4091-a004-24adfde479a8 \
  -H "X-Custom-Header: my-value" \
  -d "Some data"
```

### 3. View Captured Requests

All requests are stored in the `data/<bin-id>/` folder:

```bash
# List all requests
ls data/c5f64cbb-7962-4091-a004-24adfde479a8/

# View request contents
cat data/c5f64cbb-7962-4091-a004-24adfde479a8/1767522752499.json
```

JSON file format:
```json
{
  "timestamp": "2025-01-04T10:45:52.499+00:00",
  "method": "POST",
  "headers": {
    "content-type": "application/json",
    "user-agent": "curl/7.68.0"
  },
  "body": {
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

### 4. Custom Response

Each bin has a `response.json` file that can be customized:

```bash
# Edit response
nano data/c5f64cbb-7962-4091-a004-24adfde479a8/response.json
```

response.json format:
```json
{
  "status": 200,
  "body": {
    "status": "success",
    "message": "Request received",
    "custom_field": "custom_value"
  }
}
```

You can change the `status` code (200, 404, 500, etc.) and `body` as needed.

## 🏗️ Project Structure

```
rust-request-bin/
├── Cargo.toml          # Dependencies and project configuration
├── src/
│   └── main.rs         # Main source code
├── data/               # Request logs storage folder
│   └── <bin-id>/
│       ├── response.json           # Custom response config
│       ├── 1767522752499.json     # Request log (timestamp)
│       └── ...
└── target/             # Build artifacts
```

## 🔧 Configuration

### Port

Default port: `9997`. To change it, edit in `main.rs`:

```rust
let addr = "0.0.0.0:9997";  // Change port here
```

### Auto Cleanup

Default cleanup interval: 24 hours. To change it, edit in `main.rs`:

```rust
cleanup_old_files("data", 24).await;  // Change duration (in hours)
```

## 📦 Dependencies

- **axum**: Modern web framework for Rust
- **tokio**: Async runtime with full features
- **serde & serde_json**: JSON serialization/deserialization
- **chrono**: Date and time manipulation
- **uuid**: Generate unique identifiers
- **walkdir**: Directory traversal
- **jemallocator**: Memory allocation optimization
- **tower-http**: HTTP middleware for CORS and static file serving

## 🛠️ Development

### Build Debug
```bash
cargo build
```

### Build Release
```bash
cargo build --release
```

### Run Tests
```bash
cargo test
```

### Format Code
```bash
cargo fmt
```

### Linting
```bash
cargo clippy
```

## 📝 Use Cases

- **Webhook Testing**: Test webhook integrations from third-party services
- **API Debugging**: Debug requests sent by your application
- **HTTP Inspector**: Inspect headers, body, and metadata from HTTP requests
- **Development**: Mock endpoints for development environment
- **Monitoring**: Monitor and log incoming requests

## ⚡ Performance

- Uses **Jemalloc** for memory efficiency
- Async I/O with **Tokio** for high concurrency
- Lightweight with minimal dependencies
- Suitable for Mini PCs and embedded systems

## 🐛 Troubleshooting

### Port Already in Use
```bash
# Check what's using port 9997
lsof -i :9997

# Or use a different port
```

### Permission Denied on data folder
```bash
# Ensure data folder is writable
chmod -R 755 data/
```

## 📄 License

MIT License - Feel free to use for personal or commercial projects.

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## 📧 Contact

If you have any questions or issues, please create an issue in this repository.

---

Made with ❤️ using Rust 🦀
