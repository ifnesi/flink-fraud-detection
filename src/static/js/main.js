// GLOBAL VARS
// Events counter
var events_counter = 0;
var fraud_counter = 0;
// Previous marker for each user
var previous_markers = {};
// Map reference
var map;

//////////////////////
function generateRandomId(length = 12) {
  const array = new Uint8Array(length / 2);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('').slice(0, length);
}

//////////////////////
function appendLog(logMessage, logType = 'info') {
    // Remove welcome message if it exists
    $('.log-welcome').remove();
    
    // Create log entry with animation
    const logEntry = $(`<div class="log-entry log-${logType} fade-in">${logMessage}</div>`);
    $('#logs').append(logEntry);
    
    // Auto-scroll to bottom
    $('#logs').scrollTop($('#logs')[0].scrollHeight);
    
    // Update stats
    updateStats();
}

//////////////////////
function updateStats() {
    $('#total-events').text(events_counter);
    $('#fraud-count').text(fraud_counter);
}

//////////////////////
function formatNumber(num, decimals = 2) {
  return num.toFixed(decimals).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

//////////////////////
function hashStringToInt(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        hash = ((hash << 5) - hash) + str.charCodeAt(i); // hash * 31 + char
        hash |= 0; // Convert to 32-bit integer
    }
    return Math.abs(hash);
}

//////////////////////
function recenterMap() {
    if (map) {
        map.setView([51.5081, -0.0759], 10);
    }
}

//////////////////////
function toggleFullscreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen();
        $('#toggleFullscreen i').removeClass('bi-arrows-fullscreen').addClass('bi-fullscreen-exit');
    } else {
        if (document.exitFullscreen) {
            document.exitFullscreen();
            $('#toggleFullscreen i').removeClass('bi-fullscreen-exit').addClass('bi-arrows-fullscreen');
        }
    }
}

//////////////////////
function showAmountModal() {
    return new Promise((resolve, reject) => {
        const modal = $('#amountModal');
        const input = $('#amountInput');
        const submitBtn = $('#submitAmount');
        const cancelBtn = $('#cancelAmount');
        const closeBtn = $('#closeAmountModal');
        
        // Reset input
        input.val('');
        submitBtn.prop('disabled', true);
        
        // Show modal
        modal.addClass('show');
        
        // Focus input after animation
        setTimeout(() => input.focus(), 100);
        
        // Input validation
        input.off('input').on('input', function() {
            const value = $(this).val();
            // Allow only numbers and one decimal point
            const validPattern = /^\d*\.?\d*$/;
            
            if (!validPattern.test(value)) {
                // Remove invalid characters
                $(this).val(value.slice(0, -1));
                return;
            }
            
            // Enable/disable submit button
            const amount = parseFloat(value);
            submitBtn.prop('disabled', !value || isNaN(amount) || amount <= 0);
        });
        
        // Handle submit
        const handleSubmit = () => {
            const value = input.val();
            const amount = parseFloat(value);
            
            if (!isNaN(amount) && amount > 0) {
                modal.removeClass('show');
                resolve(amount);
                cleanup();
            }
        };
        
        // Handle cancel/close
        const handleCancel = () => {
            modal.removeClass('show');
            reject(new Error('User cancelled'));
            cleanup();
        };
        
        // Cleanup function
        const cleanup = () => {
            submitBtn.off('click', handleSubmit);
            cancelBtn.off('click', handleCancel);
            closeBtn.off('click', handleCancel);
            input.off('keypress');
            $(document).off('keydown.amountModal');
        };
        
        // Event listeners
        submitBtn.on('click', handleSubmit);
        cancelBtn.on('click', handleCancel);
        closeBtn.on('click', handleCancel);
        
        // Enter key to submit
        input.on('keypress', function(e) {
            if (e.which === 13 && !submitBtn.prop('disabled')) {
                handleSubmit();
            }
        });
        
        // ESC key to cancel
        $(document).on('keydown.amountModal', function(e) {
            if (e.key === 'Escape') {
                handleCancel();
            }
        });
    });
}

//////////////////////
$(document).ready(function(){
    // Initialize map centered around M25 near London
    map = L.map('map', {
        center: [51.5081, -0.0759],
        zoom: 10,
        doubleClickZoom: false,
        zoomControl: false // Remove default zoom control
    });

    // Add custom zoom control in bottom right
    L.control.zoom({
        position: 'bottomright'
    }).addTo(map);

    // Custom markers
    const lineColors = ['red', 'magenta', 'blue', 'green'];
    const customIcons = [
        L.icon({
            iconUrl: '/static/img/pin-red.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32],
        }),
        L.icon({
            iconUrl: '/static/img/pin-magenta.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32],
        }),
        L.icon({
            iconUrl: '/static/img/pin-blue.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32],
        }),
        L.icon({
            iconUrl: '/static/img/pin-green.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32],
        }),
    ]

    // WebSockets data handling
    const socket = io();
    socket.on("connect", () => {
        $('#ws_status')
            .removeClass('offline')
            .addClass('online');
        $('#ws_status .status-text').text('Online');
    });

    socket.on("disconnect", () => {
        $('#ws_status')
            .removeClass('online')
            .addClass('offline');
        $('#ws_status .status-text').text('Offline');
    });

    socket.on("kafka_message", (msg) => {
        const ct = msg.current_transaction_id;
        const pt = msg.previous_transaction_id;
        const max_speed = msg.max_speed;
        const speed = msg.speed;
        const user_name = msg.first_name + " " + msg.last_name;
        var status;
        var logType;
        var badgeClass;
        
        if (speed > max_speed) {
            status = "FRAUD DETECTED";
            logType = "danger";
            badgeClass = "badge-danger";
            fraud_counter++;
        }
        else {
            status = "VALID TRANSACTION";
            logType = "success";
            badgeClass = "badge-success";
        }
        
        const logMessage = `
            <div class="log-header">
                <span class="log-badge ${badgeClass}">${status}</span>
            </div>
            <div class="log-details">
                <strong>User:</strong> ${user_name}<br>
                <strong>Transaction:</strong> ${pt} → ${ct}<br>
                <strong>Speed:</strong> ${formatNumber(speed)} km/h <span style="color: var(--text-muted);">(Max: ${max_speed} km/h)</span>
            </div>
        `;
        
        appendLog(logMessage, logType);
    });

    // Load OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '© OpenStreetMap'
    }).addTo(map);

    // Map double-click event
    map.on('dblclick', async function(e) {
        // Show modal to get amount
        let amount;
        try {
            amount = await showAmountModal();
        } catch (error) {
            // User cancelled or closed modal
            return;
        }

        const userId = $('#userIdSelect').val();
        const lat = e.latlng.lat;
        const lng = e.latlng.lng;
        const timestamp = new Date().toISOString();
        const transactionId = generateRandomId();
        events_counter++;

        // Drop a marker at clicked point
        const iconId = hashStringToInt(userId) % customIcons.length;
        const marker = L.marker([lat, lng], { icon: customIcons[iconId] }).addTo(map);
        marker.bindPopup(`
            <b>Event #${events_counter}</b><br>
            <div>
            ${timestamp.replace("T", " ").replace("Z", "").substring(0, 19)}<br>
            <strong>Transaction ID:</strong> ${transactionId}<br>
            <strong>User ID:</strong> ${userId}<br>
            <strong>Amount:</strong> $${formatNumber(amount)}<br>
            <strong>Location:</strong> ${lat.toFixed(7)}, ${lng.toFixed(7)}
            </div>
        `).openPopup();
        setTimeout(() => { marker.closePopup(); }, 4000);

        // Draw a line from previous marker to current
        if (userId in previous_markers) {
            const prevMarker = previous_markers[userId];
            const latlngs = [prevMarker.getLatLng(), marker.getLatLng()];
            L.polyline(latlngs, {
                color: lineColors[iconId],
                weight: 3,
                opacity: 0.7,
                dashArray: '10, 5'
            }).addTo(map);
        }
        // Set current marker for the current user
        previous_markers[userId] = marker;

        // POST coordinates to server
        fetch('/submit-event', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                transaction_id: transactionId,
                user_id: userId,
                amount: amount,
                latitude: lat,
                longitude: lng,
                timestamp: timestamp
            })
        })
        .then(response => response.json())
        .then(data => {
            const logMessage = `
                <div class="log-header">
                    <span class="log-badge badge-success">Event #${events_counter}</span>
                    <span style="color: var(--text-muted); font-size: 0.75rem; margin-left: auto;">${userId}</span>
                </div>
                <div class="log-details">
                    <strong>Time:</strong> ${timestamp.replace("T", " ").replace("Z", "").substring(0, 19)}<br>
                    <strong>Transaction ID:</strong> ${transactionId}<br>
                    <strong>Amount:</strong> $${formatNumber(amount)}<br>
                    <strong>Coordinates:</strong> ${lat.toFixed(7)}, ${lng.toFixed(7)}
                </div>
            `;
            appendLog(logMessage, 'info');
        })
        .catch(err => {
            console.error('Error:', err);
            const errorMessage = `
                <div class="log-header">
                    <span class="log-badge badge-danger">ERROR</span>
                </div>
                <div class="log-details">
                    Failed to submit transaction. Please try again.
                </div>
            `;
            appendLog(errorMessage, 'danger');
        });
    });

    // Clear logs button
    $('#clearLogs').on('click', function() {
        if (confirm('Are you sure you want to clear all logs?')) {
            $('#logs').html('<div class="log-welcome"><i class="bi bi-info-circle"></i><p>Logs cleared. Waiting for transactions...</p></div>');
        }
    });

    // Recenter map button
    $('#recenterMap').on('click', recenterMap);

    // Fullscreen toggle button
    $('#toggleFullscreen').on('click', toggleFullscreen);

    // Handle fullscreen change
    document.addEventListener('fullscreenchange', function() {
        if (!document.fullscreenElement) {
            $('#toggleFullscreen i').removeClass('bi-fullscreen-exit').addClass('bi-arrows-fullscreen');
        }
    });

    // Initialize stats
    updateStats();
});

// Made with Bob
