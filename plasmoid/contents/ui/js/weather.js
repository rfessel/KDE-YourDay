/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Camada de dados de clima usando Open-Meteo (grátis, sem API key).
    Geocoding + previsão atual + máxima/mínima + probabilidade de chuva.
*/

function weatherIcon(code, isNight) {
    if (code === 0) return isNight ? "weather-clear-night" : "weather-clear";
    if (code === 1) return isNight ? "weather-clear-night" : "weather-clear";
    if (code === 2) return isNight ? "weather-clouds-night" : "weather-clouds";
    if (code === 3) return "weather-clouds";
    if (code === 45 || code === 48) return "weather-fog";
    if (code >= 51 && code <= 55) return "weather-showers";
    if (code === 56 || code === 57) return "weather-showers";
    if (code >= 61 && code <= 65) return "weather-showers";
    if (code === 66 || code === 67) return "weather-showers";
    if (code >= 71 && code <= 75) return "weather-snow";
    if (code === 77) return "weather-snow";
    if (code >= 80 && code <= 82) return "weather-showers";
    if (code >= 85 && code <= 86) return "weather-snow";
    if (code === 95) return "weather-storm";
    if (code === 96 || code === 99) return "weather-storm";
    return isNight ? "weather-clouds-night" : "weather-clouds";
}

function weatherIconWithRain(code, isNight, rain, showers) {
    if (rain > 0.5 || showers > 0.5) return "weather-showers";
    return weatherIcon(code, isNight);
}

function weatherDescription(code) {
    if (code === 0) return "Céu limpo";
    if (code === 1) return "Maiormente limpo";
    if (code === 2) return "Parcialmente nublado";
    if (code === 3) return "Nublado";
    if (code === 45 || code === 48) return "Nevoeiro";
    if (code >= 51 && code <= 55) return "Garoa";
    if (code === 56 || code === 57) return "Garoa gelada";
    if (code >= 61 && code <= 63) return "Chuva";
    if (code === 65) return "Chuva forte";
    if (code === 66 || code === 67) return "Chuva gelada";
    if (code >= 71 && code <= 75) return "Neve";
    if (code === 77) return "Granizo";
    if (code >= 80 && code <= 82) return "Pancadas de chuva";
    if (code >= 85 && code <= 86) return "Pancadas de neve";
    if (code === 95) return "Trovoada";
    if (code === 96 || code === 99) return "Trovoada com granizo";
    return "Sem dados";
}

function formatDayName(dateStr) {
    var days = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
    var months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
    var d = new Date(dateStr + "T12:00:00");
    var now = new Date();
    if (d.toDateString() === now.toDateString()) return "Hoje";
    return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()];
}

function formatTime(isoStr) {
    if (!isoStr) return "";
    var d = new Date(isoStr);
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
}

function fetchWeather(lat, lon, onReady, onError) {
    var url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + lat
            + "&longitude=" + lon
            + "&current=temperature_2m,weather_code,relative_humidity_2m,is_day,rain,showers,wind_speed_10m"
            + "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code,sunrise,sunset"
            + "&timezone=auto"
            + "&forecast_days=7";
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            var current = data.current || {};
            var daily = data.daily || {};
            var days = [];
            var dates = daily.time || [];
            var maxTemps = daily.temperature_2m_max || [];
            var minTemps = daily.temperature_2m_min || [];
            var codes = daily.weather_code || [];
            var rainChances = daily.precipitation_probability_max || [];
            var sunrises = daily.sunrise || [];
            var sunsets = daily.sunset || [];
            for (var i = 0; i < dates.length; i++) {
                days.push({
                    date: dates[i],
                    maxTemp: maxTemps[i],
                    minTemp: minTemps[i],
                    code: codes[i],
                    rainChance: rainChances[i],
                    sunrise: sunrises[i] || "",
                    sunset: sunsets[i] || ""
                });
            }
            onReady({
                temp: current.temperature_2m,
                code: current.weather_code,
                humidity: current.relative_humidity_2m,
                isNight: current.is_day === 0,
                rain: current.rain || 0,
                showers: current.showers || 0,
                windSpeed: current.wind_speed_10m || 0,
                maxTemp: (daily.temperature_2m_max || [])[0],
                minTemp: (daily.temperature_2m_min || [])[0],
                rainChance: (daily.precipitation_probability_max || [])[0],
                sunrise: (daily.sunrise || [])[0] || "",
                sunset: (daily.sunset || [])[0] || "",
                days: days
            });
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}

function searchCity(query, onReady, onError) {
    var url = "https://nominatim.openstreetmap.org/search"
            + "?q=" + encodeURIComponent(query)
            + "&format=json&limit=8&addressdetails=1";
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = 10000;
    xhr.setRequestHeader("User-Agent", "YourDay/1.0 (KDE Plasma widget)");
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            var cities = [];
            for (var i = 0; i < data.length; i++) {
                var r = data[i];
                var addr = r.address || {};
                var name = addr.city || addr.town || addr.village || addr.municipality || r.display_name.split(",")[0] || "";
                var state = addr.state || addr.region || "";
                var country = addr.country || "";
                var label = name;
                if (state) label += ", " + state;
                if (country) label += " (" + country + ")";
                cities.push({
                    name: name,
                    admin1: state,
                    country: country,
                    label: label,
                    lat: parseFloat(r.lat),
                    lon: parseFloat(r.lon)
                });
            }
            onReady(cities);
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}

function fetchLocationByIP(onReady, onError) {
    var url = "https://ipinfo.io/json";
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = 10000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        try {
            var data = JSON.parse(xhr.responseText);
            var loc = (data.loc || "").split(",");
            onReady({
                name: data.city || "",
                admin1: data.region || "",
                country: data.country || "",
                label: (data.city || "") + ", " + (data.region || "") + " (" + (data.country || "") + ")",
                lat: parseFloat(loc[0]) || 0,
                lon: parseFloat(loc[1]) || 0
            });
        } catch (e) {
            onError(0);
        }
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}
