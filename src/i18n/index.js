import en from './en';
import es from './es';

export const DEFAULT_LANGUAGE = 'es';
export const SUPPORTED_LANGUAGES = ['es', 'en'];

const translations = {
  es,
  en,
};

export function normalizeLanguage(value) {
  const normalized =
    typeof value === 'string' ? value.trim().toLowerCase() : '';

  return SUPPORTED_LANGUAGES.includes(normalized)
    ? normalized
    : DEFAULT_LANGUAGE;
}

export function translate(language, key) {
  const normalizedLanguage = normalizeLanguage(language);
  const selectedTranslations = translations[normalizedLanguage];

  if (Object.prototype.hasOwnProperty.call(selectedTranslations, key)) {
    return selectedTranslations[key];
  }

  if (Object.prototype.hasOwnProperty.call(es, key)) {
    return es[key];
  }

  return key;
}
