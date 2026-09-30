const fs = require('fs');
const path = require('path');

const appPath = path.join(process.cwd(), 'App.js');

console.log('');
console.log('========================================');
console.log(' PURA RUTA GUIDE - VALIDACION APP.JS');
console.log('========================================');
console.log('');

if (!fs.existsSync(appPath)) {
  console.error('[ERROR] No existe App.js');
  process.exit(1);
}

const text = fs.readFileSync(appPath, 'utf8');

console.log('[OK] App.js existe');
console.log(`[INFO] Tamaño: ${text.length} caracteres`);

let errors = 0;

// --------------------------------------------------
// 1. Corrupción UTF-8 conocida
// --------------------------------------------------

const utf8Pattern = /Ã|Â|â|ð|ƒ|€™|�/g;
const utf8Matches = text.match(utf8Pattern);

if (utf8Matches) {
  console.error(
    `[ERROR] Se detectaron ${utf8Matches.length} caracteres de posible corrupción UTF-8`
  );
  errors++;
} else {
  console.log('[OK] No se detectó corrupción UTF-8 conocida');
}

// --------------------------------------------------
// 2. Operadores ternarios corruptos
// --------------------------------------------------

const lines = text.split(/\r?\n/);

const suspiciousLines = [];

lines.forEach((line, index) => {
  if (
    /👦\s+[`A-Za-z{]/.test(line) ||
    /:\s*👦/.test(line)
  ) {
    suspiciousLines.push(index + 1);
  }
});

if (suspiciousLines.length > 0) {
  console.error(
    `[ERROR] Posibles operadores ternarios corruptos en líneas: ${suspiciousLines.join(', ')}`
  );
  errors++;
} else {
  console.log('[OK] No se detectaron operadores ternarios corruptos');
}

// --------------------------------------------------
// 3. Caracteres de reemplazo Unicode
// --------------------------------------------------

if (text.includes('\uFFFD')) {
  console.error('[ERROR] Se encontró el carácter Unicode de reemplazo �');
  errors++;
} else {
  console.log('[OK] No se encontró carácter Unicode de reemplazo');
}

// --------------------------------------------------
// 4. Buscar separadores sospechosos
// --------------------------------------------------

const suspiciousSeparators = [];

lines.forEach((line, index) => {
  if (
    /\.join\(['"`]\s*\?\s*['"`]\)/.test(line)
  ) {
    suspiciousSeparators.push(index + 1);
  }
});

if (suspiciousSeparators.length > 0) {
  console.error(
    `[ERROR] Posibles separadores corruptos en líneas: ${suspiciousSeparators.join(', ')}`
  );
  errors++;
} else {
  console.log('[OK] No se detectaron separadores corruptos');
}

// --------------------------------------------------
// 5. Verificar emojis familiares válidos
// --------------------------------------------------

if (text.includes('👨‍👩‍👧‍👦')) {
  console.log('[OK] Emoji de actividades familiares válido');
}

// --------------------------------------------------
// Resultado
// --------------------------------------------------

console.log('');
console.log('========================================');

if (errors === 0) {
  console.log(' RESULTADO: OK');
  console.log(' App.js supera las validaciones básicas.');
  console.log('========================================');
  console.log('');
  process.exit(0);
}

console.error(` RESULTADO: ERROR (${errors} problema(s))`);
console.error(' No continuar con modificaciones hasta revisar.');
console.log('========================================');
console.log('');

process.exit(1);
