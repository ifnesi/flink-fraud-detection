function generateRandomId(length = 12) {
  const array = new Uint8Array(length / 2);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('').slice(0, length);
}

function appendLog(logMessage) {
    $('#logs').append(logMessage);
    $('#logs').scrollTop($('#logs')[0].scrollHeight);
}

function formatNumber(num, decimals = 2) {
  return num.toFixed(decimals).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function hashStringToInt(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        hash = ((hash << 5) - hash) + str.charCodeAt(i); // hash * 31 + char
        hash |= 0; // Convert to 32-bit integer
    }
    return Math.abs(hash);
}

// Events counter
var events_counter = 0;

$(document).ready(function(){
    // Initialize map centered around M25 near London
    const map = L.map('map', {
        center: [51.5081, -0.0759],
        zoom: 10,
        doubleClickZoom: false
    });

    // Custom markers
    const customIcons = [
        L.icon({
            iconUrl: '/static/img/pin-red.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32]
        }),
        L.icon({
            iconUrl: '/static/img/pin-magenta.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32]
        }),
        L.icon({
            iconUrl: '/static/img/pin-blue.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32]
        }),
        L.icon({
            iconUrl: '/static/img/pin-green.png',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32]
        }),
    ]

    // WebSockets data handling
    const socket = io();
    socket.on("connect", () => {
        $('#ws_status')
        .removeClass('text-danger')
        .addClass('text-success');
        $('#ws_status').html('&#9989; Online');
    });

    socket.on("disconnect", () => {
        $('#ws_status')
        .removeClass('text-success')
        .addClass('text-danger');
        $('#ws_status').html('&#9940; Off-line');
    });

    socket.on("kafka_message", (msg) => {
        const ct = msg.current_transaction_id;
        const pt = msg.previous_transaction_id;
        const max_speed = msg.max_speed;
        const speed = msg.speed_kmph;
        const user_name = msg.first_name + " " + msg.last_name;
        var status;
        var color;
        if (speed > max_speed) {
            status = "FRAUD: Max speed exceeded";
            color = "danger"
        }
        else {
            status = "VALID";
            color = "success"
        }
        appendLog(`<span class="badge bg-${color} w-100 text-start" style="font-size:14px;">[<b>${status}</b>]<br>&#9656; ${user_name}<br>&#9656; ${pt} => ${ct}<br>&#9656; ${formatNumber(speed)} Km/h (Max: ${max_speed} Km/h)</b></span><hr class="m-1">`);
    });

    // Load OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '© OpenStreetMap'
    }).addTo(map);

    map.on('dblclick', function(e) {
        // Prompt user for amount
        const amountStr = prompt("Enter Transaction Amount ($):");
        const amount = parseFloat(amountStr);
        if (isNaN(amount)) {
            alert("Invalid amount entered.");
            return;
        }

        const userId = $('#userIdSelect').val();
        const lat = e.latlng.lat;
        const lng = e.latlng.lng;
        const timestamp = new Date().toISOString();
        const transactionId = generateRandomId();
        events_counter++;

        // Drop a marker at clicked point
        const marker = L.marker([lat, lng], { icon: customIcons[hashStringToInt(userId) % customIcons.length] }).addTo(map);
        marker.bindPopup(`
            <b>Event #${events_counter}: ${timestamp.replace("T", " ").replace("Z", "")}</b><br>
            - Transaction ID: ${transactionId}<br>
            - User ID: ${userId}<br>
            - Amount: $ ${formatNumber(amount)}<br>
            - Lat: ${lat.toFixed(7)}<br>
            - Lng: ${lng.toFixed(7)}`).openPopup();
        setTimeout(() => { marker.closePopup(); }, 4000);

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
            appendLog(`
                <span style="text-decoration:underline;"><b>Event #${events_counter} [${userId}]</b></span>:<br>
                - timestamp: ${timestamp.replace("T", " ").replace("Z", "")}<br>
                - transaction_id: ${transactionId}<br>
                - amount: $ ${formatNumber(amount)}<br>
                - coordinates: ${lat.toFixed(7)}, ${lng.toFixed(7)}<hr class="m-1">`);
        })
        .catch(err => {
            console.error('Error:', err);
        });
    });
});