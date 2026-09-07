/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Camada de dados de clima usando Open-Meteo (grátis, sem API key).
    Geocoding + previsão atual + máxima/mínima + probabilidade de chuva.
*/

.pragma library

var _iconTable = {
    0: "clear", 1: "clear", 2: "clouds", 3: "clouds",
    45: "fog", 48: "fog",
    51: "showers", 53: "showers", 55: "showers",
    56: "showers", 57: "showers",
    61: "showers", 63: "showers", 65: "showers",
    66: "showers", 67: "showers",
    71: "snow", 73: "snow", 75: "snow", 77: "snow",
    80: "showers", 81: "showers", 82: "showers",
    85: "snow", 86: "snow",
    95: "storm", 96: "storm", 99: "storm"
};

var _nightIcons = {
    clear: "weather-clear-night",
    clouds: "weather-clouds-night"
};

var _dayIcons = {
    clear: "weather-clear",
    clouds: "weather-clouds",
    fog: "weather-fog",
    showers: "weather-showers",
    snow: "weather-snow",
    storm: "weather-storm"
};

var _descTable = {
    0: "Céu limpo", 1: "Maiormente limpo", 2: "Parcialmente nublado", 3: "Nublado",
    45: "Nevoeiro", 48: "Nevoeiro",
    51: "Garoa", 53: "Garoa", 55: "Garoa",
    56: "Garoa gelada", 57: "Garoa gelada",
    61: "Chuva", 63: "Chuva", 65: "Chuva forte",
    66: "Chuva gelada", 67: "Chuva gelada",
    71: "Neve", 73: "Neve", 75: "Neve", 77: "Granizo",
    80: "Pancadas de chuva", 81: "Pancadas de chuva", 82: "Pancadas de chuva",
    85: "Pancadas de neve", 86: "Pancadas de neve",
    95: "Trovoada", 96: "Trovoada com granizo", 99: "Trovoada com granizo"
};

function weatherIcon(code, isNight) {
    var key = _iconTable[code] || "clouds";
    if (isNight && _nightIcons[key]) return _nightIcons[key];
    return _dayIcons[key] || "weather-clouds";
}

function weatherIconWithRain(code, isNight, rain, showers) {
    if (rain > 0.5 || showers > 0.5) return "weather-showers";
    return weatherIcon(code, isNight);
}

function weatherDescription(code) {
    return _descTable[code] || "Sem dados";
}

function formatTime(isoStr) {
    if (!isoStr) return "";
    var d = new Date(isoStr);
    var h = d.getHours();
    var m = d.getMinutes();
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
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
    xhr.timeout = 10000;
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
