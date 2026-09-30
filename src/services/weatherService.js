const OPEN_METEO_FORECAST_URL =
  'https://api.open-meteo.com/v1/forecast';

const WEATHER_DESCRIPTIONS = {
  0: 'Despejado',
  1: 'Mayormente despejado',
  2: 'Parcialmente nublado',
  3: 'Nublado',
  45: 'Neblina',
  48: 'Neblina',
  51: 'Llovizna',
  53: 'Llovizna',
  55: 'Llovizna',
  56: 'Llovizna helada',
  57: 'Llovizna helada',
  61: 'Lluvia',
  63: 'Lluvia',
  65: 'Lluvia',
  66: 'Lluvia helada',
  67: 'Lluvia helada',
  71: 'Nieve',
  73: 'Nieve',
  75: 'Nieve',
  77: 'Nieve',
  80: 'Chubascos',
  81: 'Chubascos',
  82: 'Chubascos',
  85: 'Chubascos de nieve',
  86: 'Chubascos de nieve',
  95: 'Tormenta',
  96: 'Tormenta con granizo',
  99: 'Tormenta con granizo',
};

const REQUEST_TIMEOUT_MS = 6000;

function getWeatherDescription(weatherCode) {
  return WEATHER_DESCRIPTIONS[weatherCode] ||
    'Condiciones variables';
}

export async function getDestinationWeather({
  latitude,
  longitude,
  timezone,
}) {
  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    REQUEST_TIMEOUT_MS
  );

  try {
    const query = new URLSearchParams({
      latitude: String(latitude),
      longitude: String(longitude),
      current: 'temperature_2m,weather_code,is_day',
      temperature_unit: 'celsius',
      timezone,
    });

    const response = await fetch(
      `${OPEN_METEO_FORECAST_URL}?${query.toString()}`,
      { signal: controller.signal }
    );

    if (!response.ok) {
      throw new Error(
        `Open-Meteo respondió con estado ${response.status}.`
      );
    }

    const data = await response.json();
    const current = data?.current;
    const temperature = Number(current?.temperature_2m);
    const weatherCode = Number(current?.weather_code);

    if (
      !Number.isFinite(temperature) ||
      !Number.isFinite(weatherCode)
    ) {
      throw new Error('Open-Meteo no devolvió el clima actual esperado.');
    }

    return {
      temperature,
      weatherCode,
      description: getWeatherDescription(weatherCode),
      isDay: Number(current?.is_day) === 1,
      fetchedAt: new Date().toISOString(),
    };
  } finally {
    clearTimeout(timeoutId);
  }
}
