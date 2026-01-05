// ========================================
// State Management
// ========================================
const state = {
    bins: [],
    currentBin: null,
    baseUrl: window.location.origin
};

// ========================================
// DOM Elements
// ========================================
const elements = {
    binsGrid: document.getElementById('binsGrid'),
    createBinBtn: document.getElementById('createBinBtn'),
    editorModal: document.getElementById('editorModal'),
    closeModal: document.getElementById('closeModal'),
    modalBinId: document.getElementById('modalBinId'),
    modalBinUrl: document.getElementById('modalBinUrl'),
    copyBinId: document.getElementById('copyBinId'),
    copyBinUrl: document.getElementById('copyBinUrl'),
    statusCode: document.getElementById('statusCode'),
    responseBody: document.getElementById('responseBody'),
    jsonError: document.getElementById('jsonError'),
    saveResponse: document.getElementById('saveResponse'),
    recentLogs: document.getElementById('recentLogs'),
    toast: document.getElementById('toast')
};

// ========================================
// API Functions
// ========================================
const api = {
    async listBins() {
        const response = await fetch('/api/bins');
        if (!response.ok) throw new Error('Failed to fetch bins');
        return await response.json();
    },

    async getBinDetail(id) {
        const response = await fetch(`/api/bins/${id}`);
        if (!response.ok) throw new Error('Failed to fetch bin detail');
        return await response.json();
    },

    async updateBinResponse(id, status, body) {
        const response = await fetch(`/api/bins/${id}/response`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ status, body })
        });
        if (!response.ok) throw new Error('Failed to update response');
        return response;
    },

    async createBin() {
        const response = await fetch('/create');
        if (!response.ok) throw new Error('Failed to create bin');
        const text = await response.text();
        // Parse the response text to extract bin ID
        const match = text.match(/Bin ID: ([^\n]+)/);
        return match ? match[1] : null;
    }
};

// ========================================
// UI Functions
// ========================================
const ui = {
    showToast(message, type = 'success') {
        elements.toast.textContent = message;
        elements.toast.className = `toast ${type} active`;

        setTimeout(() => {
            elements.toast.classList.remove('active');
        }, 3000);
    },

    showModal() {
        elements.editorModal.classList.add('active');
        document.body.style.overflow = 'hidden';
    },

    hideModal() {
        elements.editorModal.classList.remove('active');
        document.body.style.overflow = '';
        state.currentBin = null;
    },

    validateJSON(text) {
        try {
            JSON.parse(text);
            elements.jsonError.classList.remove('active');
            elements.jsonError.textContent = '';
            return true;
        } catch (e) {
            elements.jsonError.classList.add('active');
            elements.jsonError.textContent = `Invalid JSON: ${e.message}`;
            return false;
        }
    },

    formatDate(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const diff = now - date;

        const minutes = Math.floor(diff / 60000);
        const hours = Math.floor(diff / 3600000);
        const days = Math.floor(diff / 86400000);

        if (minutes < 1) return 'Just now';
        if (minutes < 60) return `${minutes}m ago`;
        if (hours < 24) return `${hours}h ago`;
        if (days < 7) return `${days}d ago`;

        return date.toLocaleDateString('id-ID', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    },

    renderBins(bins) {
        if (bins.length === 0) {
            elements.binsGrid.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">📦</div>
                    <p>No bins yet. Create your first bin to get started!</p>
                </div>
            `;
            return;
        }

        elements.binsGrid.innerHTML = bins.map(bin => `
            <div class="bin-card" data-bin-id="${bin.id}">
                <div class="bin-card-header">
                    <div class="bin-id">${bin.id}</div>
                    <div class="bin-status">
                        <span>●</span> Active
                    </div>
                </div>
                <div class="bin-url">${bin.url}</div>
                <div class="bin-meta">
                    <span>Created ${ui.formatDate(bin.created)}</span>
                    <span>Click to edit →</span>
                </div>
            </div>
        `).join('');

        // Add click handlers
        document.querySelectorAll('.bin-card').forEach(card => {
            card.addEventListener('click', () => {
                const binId = card.dataset.binId;
                openBinEditor(binId);
            });
        });
    },

    renderBinDetail(detail) {
        state.currentBin = detail;

        // Set bin info
        elements.modalBinId.textContent = detail.id;
        elements.modalBinUrl.textContent = `${state.baseUrl}${detail.url}`;

        // Set response config
        elements.statusCode.value = detail.response.status;
        elements.responseBody.value = JSON.stringify(detail.response.body, null, 2);

        // Render logs
        ui.renderLogs(detail.recent_logs);

        ui.showModal();
    },

    renderLogs(logs) {
        if (logs.length === 0) {
            elements.recentLogs.innerHTML = `
                <div class="logs-empty">
                    No requests captured yet. Send a request to this bin to see it here.
                </div>
            `;
            return;
        }

        elements.recentLogs.innerHTML = logs.map(log => `
            <div class="log-entry">
                <div class="log-header">
                    <span class="log-method">${log.method}</span>
                    <span class="log-timestamp">${ui.formatDate(log.timestamp)}</span>
                </div>
                <div class="log-body">${JSON.stringify(log.body, null, 2)}</div>
            </div>
        `).join('');
    }
};

// ========================================
// Core Functions
// ========================================
async function loadBins() {
    try {
        elements.binsGrid.innerHTML = '<div class="loading">Loading bins...</div>';
        const bins = await api.listBins();
        state.bins = bins;
        ui.renderBins(bins);
    } catch (error) {
        console.error('Error loading bins:', error);
        ui.showToast('Failed to load bins', 'error');
        elements.binsGrid.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">⚠️</div>
                <p>Failed to load bins. Please refresh the page.</p>
            </div>
        `;
    }
}

async function openBinEditor(binId) {
    try {
        const detail = await api.getBinDetail(binId);
        ui.renderBinDetail(detail);
    } catch (error) {
        console.error('Error loading bin detail:', error);
        ui.showToast('Failed to load bin details', 'error');
    }
}

async function createNewBin() {
    try {
        elements.createBinBtn.disabled = true;
        elements.createBinBtn.textContent = 'Creating...';

        const binId = await api.createBin();

        if (binId) {
            ui.showToast('Bin created successfully!');
            await loadBins();
            // Auto-open the new bin
            setTimeout(() => openBinEditor(binId), 500);
        }
    } catch (error) {
        console.error('Error creating bin:', error);
        ui.showToast('Failed to create bin', 'error');
    } finally {
        elements.createBinBtn.disabled = false;
        elements.createBinBtn.innerHTML = '<span class="btn-icon">+</span> Create New Bin';
    }
}

async function saveResponseConfig() {
    if (!state.currentBin) return;

    const bodyText = elements.responseBody.value.trim();

    // Validate JSON
    if (!ui.validateJSON(bodyText)) {
        ui.showToast('Please fix JSON errors before saving', 'error');
        return;
    }

    try {
        elements.saveResponse.disabled = true;
        elements.saveResponse.textContent = 'Saving...';

        const status = parseInt(elements.statusCode.value);
        const body = JSON.parse(bodyText);

        await api.updateBinResponse(state.currentBin.id, status, body);

        ui.showToast('Response configuration saved!');

        // Update current bin state
        state.currentBin.response.status = status;
        state.currentBin.response.body = body;

    } catch (error) {
        console.error('Error saving response:', error);
        ui.showToast('Failed to save configuration', 'error');
    } finally {
        elements.saveResponse.disabled = false;
        elements.saveResponse.innerHTML = '<span class="btn-icon">💾</span> Save Configuration';
    }
}

function copyToClipboard(text, label) {
    navigator.clipboard.writeText(text).then(() => {
        ui.showToast(`${label} copied to clipboard!`);
    }).catch(err => {
        console.error('Failed to copy:', err);
        ui.showToast('Failed to copy to clipboard', 'error');
    });
}

// ========================================
// Event Listeners
// ========================================
elements.createBinBtn.addEventListener('click', createNewBin);
elements.closeModal.addEventListener('click', ui.hideModal);
elements.saveResponse.addEventListener('click', saveResponseConfig);

elements.copyBinId.addEventListener('click', () => {
    copyToClipboard(elements.modalBinId.textContent, 'Bin ID');
});

elements.copyBinUrl.addEventListener('click', () => {
    copyToClipboard(elements.modalBinUrl.textContent, 'Bin URL');
});

// Real-time JSON validation
elements.responseBody.addEventListener('input', () => {
    const text = elements.responseBody.value.trim();
    if (text) {
        ui.validateJSON(text);
    } else {
        elements.jsonError.classList.remove('active');
    }
});

// Close modal on background click
elements.editorModal.addEventListener('click', (e) => {
    if (e.target === elements.editorModal) {
        ui.hideModal();
    }
});

// Close modal on Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && elements.editorModal.classList.contains('active')) {
        ui.hideModal();
    }
});

// ========================================
// Initialize App
// ========================================
document.addEventListener('DOMContentLoaded', () => {
    loadBins();

    // Auto-refresh bins every 30 seconds
    setInterval(loadBins, 30000);
});
