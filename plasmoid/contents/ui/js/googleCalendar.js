/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Integração com Google Calendar API v3.
    Autenticação via Service Account (JWT).
    Mais simples que OAuth para uso em widgets desktop.
*/

.pragma library

var TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";
var CALENDAR_API = "https://www.googleapis.com/calendar/v3";
var SCOPES = "https://www.googleapis.com/auth/calendar";

// Gera JWT para autenticação de Service Account
function generateJWT(serviceAccountEmail, privateKey) {
    var header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));

    var now = Math.floor(Date.now() / 1000);
    var payload = base64UrlEncode(JSON.stringify({
        iss: serviceAccountEmail,
        scope: SCOPES,
        aud: TOKEN_ENDPOINT,
        iat: now,
        exp: now + 3600
    }));

    var signatureInput = header + "." + payload;
    var signature = signRS256(signatureInput, privateKey);

    return signatureInput + "." + signature;
}

// Assina RS256 (simplificado - usa SubtleCrypto quando disponível)
function signRS256(data, privateKeyPem) {
    // Para widgets KDE/Qt, usamos uma abordagem simplificada
    // O Service Account JSON deve conter a chave privada
    try {
        var encoder = new TextEncoder();
        var dataBuffer = encoder.encode(data);

        // Remove headers PEM e converte para binário
        var keyData = privateKeyPem
            .replace(/-----BEGIN PRIVATE KEY-----/g, "")
            .replace(/-----END PRIVATE KEY-----/g, "")
            .replace(/\s/g, "");

        var binaryString = atob(keyData);
        var bytes = new Uint8Array(binaryString.length);
        for (var i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
        }

        return crypto.subtle.importKey(
            "pkcs8",
            bytes,
            { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
            false,
            ["sign"]
        ).then(function(key) {
            return crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, dataBuffer);
        }).then(function(signature) {
            return base64UrlEncode(new Uint8Array(signature));
        });
    } catch (e) {
        console.warn("[googleCalendar] Erro assinar JWT:", e);
        return "";
    }
}

function base64UrlEncode(input) {
    var str;
    if (typeof input === "string") {
        str = input;
    } else {
        var bytes = new Uint8Array(input);
        var binary = "";
        for (var i = 0; i < bytes.length; i++) {
            binary += String.fromCharCode(bytes[i]);
        }
        str = binary;
    }
    return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Obtém access token usando JWT
function getAccessToken(serviceAccountEmail, privateKey, onReady, onError) {
    var jwtPromise = generateJWT(serviceAccountEmail, privateKey);

    if (jwtPromise && typeof jwtPromise.then === "function") {
        jwtPromise.then(function(jwt) {
            requestToken(jwt, onReady, onError);
        }).catch(function(e) {
            onError(-3);
        });
    } else if (jwtPromise) {
        requestToken(jwtPromise, onReady, onError);
    } else {
        onError(-3);
    }
}

function requestToken(jwt, onReady, onError) {
    var params = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"
        + "&assertion=" + encodeURIComponent(jwt);

    var xhr = new XMLHttpRequest();
    xhr.open("POST", TOKEN_ENDPOINT, true);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            onReady({
                accessToken: data.access_token,
                expiresIn: data.expires_in,
                tokenType: data.token_type
            });
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(params);
}

function listCalendars(accessToken, onReady, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", CALENDAR_API + "/users/me/calendarList?maxResults=50", true);
    xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            var calendars = [];
            var items = data.items || [];
            for (var i = 0; i < items.length; i++) {
                calendars.push({
                    id: items[i].id,
                    summary: items[i].summary || "",
                    primary: items[i].primary || false,
                    accessRole: items[i].accessRole || ""
                });
            }
            onReady(calendars);
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}

function listEvents(accessToken, calendarId, timeMin, timeMax, onReady, onError) {
    var url = CALENDAR_API + "/calendars/" + encodeURIComponent(calendarId) + "/events"
        + "?timeMin=" + encodeURIComponent(timeMin)
        + "&timeMax=" + encodeURIComponent(timeMax)
        + "&singleEvents=true"
        + "&orderBy=startTime"
        + "&maxResults=250";

    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            var events = [];
            var items = data.items || [];
            for (var i = 0; i < items.length; i++) {
                var ev = items[i];
                var start, end, allDay;
                if (ev.start.date) {
                    start = new Date(ev.start.date + "T00:00:00").getTime();
                    end = new Date(ev.end.date + "T00:00:00").getTime();
                    allDay = true;
                } else {
                    start = new Date(ev.start.dateTime).getTime();
                    end = new Date(ev.end.dateTime).getTime();
                    allDay = false;
                }
                events.push({
                    googleId: ev.id,
                    title: ev.summary || "(sem título)",
                    start: start,
                    end: end,
                    allDay: allDay,
                    description: ev.description || "",
                    location: ev.location || "",
                    source: "google",
                    recurringEventId: ev.recurringEventId || null
                });
            }
            onReady(events);
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}

function createEvent(accessToken, calendarId, event, onReady, onError) {
    var body = buildEventBody(event);

    var xhr = new XMLHttpRequest();
    xhr.open("POST", CALENDAR_API + "/calendars/" + encodeURIComponent(calendarId) + "/events", true);
    xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            onReady({ googleId: data.id });
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(JSON.stringify(body));
}

function updateEvent(accessToken, calendarId, googleId, event, onReady, onError) {
    var body = buildEventBody(event);

    var xhr = new XMLHttpRequest();
    xhr.open("PUT", CALENDAR_API + "/calendars/" + encodeURIComponent(calendarId) + "/events/" + encodeURIComponent(googleId), true);
    xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            onReady({ googleId: data.id });
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(JSON.stringify(body));
}

function deleteEvent(accessToken, calendarId, googleId, onReady, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("DELETE", CALENDAR_API + "/calendars/" + encodeURIComponent(calendarId) + "/events/" + encodeURIComponent(googleId), true);
    xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status === 204 || xhr.status === 200) {
            onReady();
        } else {
            onError(xhr.status);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}

function buildEventBody(event) {
    var body = {
        summary: event.title,
        description: event.description || "",
        location: event.location || ""
    };

    if (event.allDay) {
        var startDate = new Date(event.start);
        var endDate = new Date(event.end);
        body.start = {
            date: formatDateOnly(startDate)
        };
        body.end = {
            date: formatDateOnly(endDate)
        };
    } else {
        body.start = {
            dateTime: new Date(event.start).toISOString()
        };
        body.end = {
            dateTime: new Date(event.end).toISOString()
        };
    }

    return body;
}

function formatDateOnly(d) {
    var y = d.getFullYear();
    var m = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1);
    var day = (d.getDate() < 10 ? "0" : "") + d.getDate();
    return y + "-" + m + "-" + day;
}

function isTokenExpired(tokenExpiry) {
    if (!tokenExpiry) return true;
    return Date.now() >= (tokenExpiry - 60000);
}

// Parse Service Account JSON e extrai email e chave privada
function parseServiceAccount(json) {
    try {
        var sa = JSON.parse(json);
        return {
            email: sa.client_email || "",
            privateKey: sa.private_key || "",
            projectId: sa.project_id || ""
        };
    } catch (e) {
        return null;
    }
}
