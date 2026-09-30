import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useState } from 'react';
import {
  getDestinationWeather,
} from '../services/weatherService';

const WEATHER_CACHE_PREFIX = 'weather:v1';
const WEATHER_CACHE_TTL_MS = 45 * 60 * 1000;

function getCacheKey(destinationId) {
  return `${WEATHER_CACHE_PREFIX}:${destinationId}`;
}

function isFreshWeather(weather) {
  const fetchedAtMilliseconds = Date.parse(weather?.fetchedAt);

  return (
    Number.isFinite(fetchedAtMilliseconds) &&
    Date.now() - fetchedAtMilliseconds <= WEATHER_CACHE_TTL_MS
  );
}

async function getCachedWeather(cacheKey) {
  const storedWeather = await AsyncStorage.getItem(cacheKey);

  if (!storedWeather) {
    return null;
  }

  try {
    const weather = JSON.parse(storedWeather);
    return isFreshWeather(weather) ? weather : null;
  } catch {
    return null;
  }
}

export function useDestinationWeather(destination) {
  const [weather, setWeather] = useState(null);
  const destinationId = destination?.id;
  const latitude = destination?.latitude;
  const longitude = destination?.longitude;
  const timezone = destination?.timezone;

  useEffect(() => {
    let isMounted = true;

    if (
      !destinationId ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      !timezone
    ) {
      setWeather(null);
      return undefined;
    }

    const loadWeather = async () => {
      const cacheKey = getCacheKey(destinationId);
      const cachedWeather = await getCachedWeather(cacheKey);

      if (isMounted && cachedWeather) {
        setWeather(cachedWeather);
      }

      try {
        const fetchedWeather = await getDestinationWeather({
          latitude,
          longitude,
          timezone,
        });

        await AsyncStorage.setItem(
          cacheKey,
          JSON.stringify(fetchedWeather)
        );

        if (isMounted) {
          setWeather(fetchedWeather);
        }
      } catch {
        if (isMounted && !cachedWeather) {
          setWeather(null);
        }
      }
    };

    loadWeather();

    return () => {
      isMounted = false;
    };
  }, [destinationId, latitude, longitude, timezone]);

  return weather;
}
