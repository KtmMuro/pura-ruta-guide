import { supabase } from './supabase';
import React, { useEffect, useState } from 'react';
import * as ImagePicker from 'expo-image-picker';
import {
  Alert,
  Image,
  ImageBackground,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { StatusBar as ExpoStatusBar } from 'expo-status-bar';

const colors = {
  forest: '#052513',
  panel: '#082D18',
  gold: '#F2B534',
  pale: '#D8E3D9',
  muted: '#94AA9A',
};

const hero =
  'https://images.unsplash.com/photo-1518182170546-07661fd94144?auto=format&fit=crop&w=1200&q=85';
const hotSprings =
  'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=700&q=85';

const arenal =
  'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=700&q=85';

/* =========================================================
   CATEGORÍAS
   ========================================================= */

const categoryGroups = [
  {
    title: 'Turismo',
    categories: [
      ['🏨', 'Hoteles'],
      ['🛖', 'Cabinas'],
      ['🥾', 'Tours'],
      ['◈', 'Atracciones'],
      ['♨️', 'Termales'],
    ],
  },
  {
    title: 'Servicios',
    categories: [
      ['🍽️', 'Comida'],
      ['☕', 'Cafés'],
      ['🚐', 'Transporte'],
      ['🚗', 'Renta'],
    ],
  },
  {
    title: 'Comercio',
    categories: [
      ['🛍️', 'Comercio'],
      ['🏠', 'Bienes Raíces'],
    ],
  },
];

const categoryMap = {
  Hoteles: 'Hospedaje',
  Cabinas: 'Hospedaje',
  Tours: 'Tours',
  Atracciones: 'Atracciones',
  Termales: 'Termales',
  Comida: 'Restaurante',
  Cafés: 'Cafés',
  Transporte: 'Transporte',
  Renta: 'Renta',
  Comercio: 'Comercio',
  'Bienes Raíces': 'Bienes Raíces',
};

const businessCategories = [
  'Hospedaje',
  'Tours',
  'Atracciones',
  'Termales',
  'Restaurante',
  'Cafés',
  'Transporte',
  'Renta',
  'Comercio',
  'Bienes Raíces',
];

function guessImageContentType(uri) {
  const lower = (uri || '').toLowerCase();

  if (lower.includes('.png')) {
    return 'image/png';
  }

  if (lower.includes('.webp')) {
    return 'image/webp';
  }

  if (lower.includes('.heic')) {
    return 'image/heic';
  }

  return 'image/jpeg';
}

function guessImageExtension(contentType) {
  if (contentType === 'image/png') {
    return 'png';
  }

  if (contentType === 'image/webp') {
    return 'webp';
  }

  if (contentType === 'image/heic') {
    return 'heic';
  }

  return 'jpg';
}

async function uploadBusinessPhoto(userId, uri) {
  const contentType = guessImageContentType(uri);
  const extension = guessImageExtension(contentType);
  const path = `${userId}/${Date.now()}.${extension}`;

  const response = await fetch(uri);

  if (!response.ok) {
    throw new Error('No se pudo leer la fotografía seleccionada.');
  }

  const arrayBuffer = await response.arrayBuffer();

  const { error } = await supabase.storage
    .from('business-photos')
    .upload(path, arrayBuffer, {
      contentType,
      upsert: false,
    });

  if (error) {
    throw error;
  }

  const { data } = supabase.storage
    .from('business-photos')
    .getPublicUrl(path);

  return data.publicUrl;
}

/* =========================================================
   BOTÓN
   ========================================================= */

function Button({ title, onPress, variant = 'gold', disabled = false }) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={[
        styles.button,
        variant === 'outline' && styles.buttonOutline,
        disabled && styles.buttonDisabled,
      ]}
    >
      <Text
        style={[
          styles.buttonText,
          variant === 'outline' && styles.buttonTextOutline,
        ]}
      >
        {title}
      </Text>
    </Pressable>
  );
}

/* =========================================================
   SPLASH
   ========================================================= */

function Splash({ onContinue }) {
  return (
    <ImageBackground source={{ uri: hero }} style={styles.splash}>
      <View style={styles.overlay} />

      <SafeAreaView style={styles.splashContent}>
        <Text style={styles.mark}>⌕</Text>

        <View style={styles.splashCenter}>
          <Text style={styles.brand}>
            PURA RUTA{`\n`}GUIDE
          </Text>

          <Text style={styles.tagline}>
            Explora. Descubre. Vive Costa Rica.
          </Text>

          <View style={styles.progressTrack}>
            <View style={styles.progress} />
          </View>

          <Text style={styles.loading}>
            BUSCANDO RUTAS...
          </Text>

          <View style={styles.languages}>
            <Text style={styles.languageActive}>
              ESPAÑOL
            </Text>

            <Text style={styles.language}>
              ENGLISH
            </Text>
          </View>
        </View>

        <View>
          <Text style={styles.footer}>
            Versión 1.0{`\n`}
            Hecho en Costa Rica 🇨🇷
          </Text>

          <Button
            title="Continuar"
            onPress={onContinue}
          />
        </View>
      </SafeAreaView>
    </ImageBackground>
  );
}

/* =========================================================
   LOGIN / REGISTRO / RECUPERACIÓN
   ========================================================= */

function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [mode, setMode] = useState('login');

  const submitLogin = async () => {
    if (!email.trim() || !password) {
      setMessage('Ingresa tu correo y contraseña.');
      return;
    }

    try {
      setLoading(true);
      setMessage('Iniciando sesión...');

      const { data, error } =
        await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });

      if (error) {
        console.log('Error Supabase:', error.message);
        setMessage(error.message);
        return;
      }

      if (data?.session) {
        console.log(
          'Login exitoso:',
          data.user?.email
        );

        setMessage('');
        onLogin();
      } else {
        setMessage(
          'No se pudo establecer la sesión.'
        );
      }
    } catch (error) {
      console.log(
        'Error inesperado:',
        error
      );

      setMessage(
        'Ocurrió un error al iniciar sesión.'
      );
    } finally {
      setLoading(false);
    }
  };

  const submitRegister = async () => {
    if (
      !email.trim() ||
      !password ||
      !confirmPassword
    ) {
      setMessage(
        'Completa todos los campos.'
      );
      return;
    }

    if (password.length < 6) {
      setMessage(
        'La contraseña debe tener al menos 6 caracteres.'
      );
      return;
    }

    if (password !== confirmPassword) {
      setMessage(
        'Las contraseñas no coinciden.'
      );
      return;
    }

    try {
      setLoading(true);
      setMessage('Creando cuenta...');

      const { data, error } =
        await supabase.auth.signUp({
          email: email.trim(),
          password,
        });

      if (error) {
        console.log(
          'Error registro:',
          error.message
        );

        setMessage(error.message);
        return;
      }

      if (data?.session) {
        setMessage(
          'Cuenta creada correctamente.'
        );

        onLogin();
      } else {
        setMessage(
          'Cuenta creada. Revisa tu correo para confirmar tu cuenta.'
        );

        setMode('login');
      }
    } catch (error) {
      console.log(
        'Error inesperado:',
        error
      );

      setMessage(
        'Ocurrió un error al crear la cuenta.'
      );
    } finally {
      setLoading(false);
    }
  };

  const submitForgotPassword = async () => {
    if (!email.trim()) {
      setMessage(
        'Ingresa tu correo electrónico.'
      );
      return;
    }

    try {
      setLoading(true);
      setMessage('Enviando correo...');

      const { error } =
        await supabase.auth.resetPasswordForEmail(
          email.trim(),
          {
            redirectTo: 'puraruta://reset-password',
          }
        );

      if (error) {
        console.log(
          'Error recuperación:',
          error.message
        );

        setMessage(error.message);
        return;
      }

      setMessage(
        'Te enviamos un correo para recuperar tu contraseña.'
      );
    } catch (error) {
      console.log(
        'Error inesperado:',
        error
      );

      setMessage(
        'No se pudo enviar el correo de recuperación.'
      );
    } finally {
      setLoading(false);
    }
  };

  const title =
    mode === 'register'
      ? 'Crear una cuenta'
      : mode === 'forgot'
      ? 'Recuperar contraseña'
      : (
          <>
            ¡Bienvenido a Pura Ruta{`\n`}
            Guide!
          </>
        );

  const buttonTitle =
    mode === 'register'
      ? loading
        ? 'Creando cuenta...'
        : 'Crear cuenta'
      : mode === 'forgot'
      ? loading
        ? 'Enviando...'
        : 'Enviar correo'
      : loading
      ? 'Iniciando sesión...'
      : 'Iniciar sesión';

  const submit =
    mode === 'register'
      ? submitRegister
      : mode === 'forgot'
      ? submitForgotPassword
      : submitLogin;

  return (
    <ImageBackground
      source={{ uri: hero }}
      style={styles.loginBg}
    >
      <View style={styles.darkOverlay} />

      <SafeAreaView style={styles.loginWrap}>
        <Pressable
          onPress={() => {
            if (mode !== 'login') {
              setMode('login');
              setMessage('');
            } else {
              Alert.alert(
                'Pura Ruta',
                'Puedes iniciar sesión o crear una cuenta gratis.'
              );
            }
          }}
        >
          <Text style={styles.back}>‹</Text>
        </Pressable>

        <View style={styles.loginBody}>
          <Text style={styles.loginTitle}>
            {title}
          </Text>

          <Text style={styles.subtitle}>
            {mode === 'register'
              ? 'Crea tu cuenta y comienza a descubrir Costa Rica'
              : mode === 'forgot'
              ? 'Te ayudaremos a recuperar el acceso a tu cuenta'
              : 'Descubre Costa Rica como nunca antes'}
          </Text>

          <Text style={styles.label}>
            CORREO ELECTRÓNICO
          </Text>

          <TextInput
            value={email}
            onChangeText={(text) => {
              setEmail(text);
              setMessage('');
            }}
            style={styles.input}
            placeholder="Correo electrónico"
            placeholderTextColor={colors.muted}
            keyboardType="email-address"
            autoCapitalize="none"
            autoCorrect={false}
          />

          {mode !== 'forgot' && (
            <>
              <Text style={styles.label}>
                CONTRASEÑA
              </Text>

              <TextInput
                value={password}
                onChangeText={(text) => {
                  setPassword(text);
                  setMessage('');
                }}
                style={styles.input}
                placeholder="Contraseña"
                placeholderTextColor={colors.muted}
                secureTextEntry
              />
            </>
          )}

          {mode === 'register' && (
            <>
              <Text style={styles.label}>
                CONFIRMAR CONTRASEÑA
              </Text>

              <TextInput
                value={confirmPassword}
                onChangeText={(text) => {
                  setConfirmPassword(text);
                  setMessage('');
                }}
                style={styles.input}
                placeholder="Repite tu contraseña"
                placeholderTextColor={colors.muted}
                secureTextEntry
              />
            </>
          )}

          <Button
            title={buttonTitle}
            onPress={submit}
            disabled={loading}
          />

          {!!message && (
            <Text style={styles.help}>
              {message}
            </Text>
          )}

          {mode === 'login' && (
            <>
              <Pressable
                onPress={() => {
                  setMode('register');
                  setMessage('');
                }}
              >
                <Text style={styles.help}>
                  ¿No tienes cuenta?{' '}
                  <Text style={styles.goldText}>
                    Regístrate aquí
                  </Text>
                </Text>
              </Pressable>

              <Pressable
                onPress={() => {
                  setMode('forgot');
                  setMessage('');
                }}
              >
                <Text style={styles.help}>
                  ¿Olvidaste tu contraseña?
                </Text>
              </Pressable>
            </>
          )}

          {mode === 'register' && (
            <Pressable
              onPress={() => {
                setMode('login');
                setMessage('');
              }}
            >
              <Text style={styles.help}>
                ¿Ya tienes una cuenta?{' '}
                <Text style={styles.goldText}>
                  Inicia sesión
                </Text>
              </Text>
            </Pressable>
          )}

          {mode === 'forgot' && (
            <Pressable
              onPress={() => {
                setMode('login');
                setMessage('');
              }}
            >
              <Text style={styles.help}>
                Volver a iniciar sesión
              </Text>
            </Pressable>
          )}
        </View>
      </SafeAreaView>
    </ImageBackground>
  );
}

/* =========================================================
   TARJETA DE LUGAR
   ========================================================= */

function PlaceCard({
  image,
  label,
  title,
  detail,
}) {
  return (
    <Pressable
      onPress={() =>
        Alert.alert(
          title,
          `${detail}\n\nPróximamente: ficha del lugar, reseñas y cómo llegar.`
        )
      }
      style={styles.card}
    >
      <ImageBackground
        source={{ uri: image }}
        style={styles.cardImage}
      >
        <Text style={styles.cardLabel}>
          {label}
        </Text>
      </ImageBackground>

      <Text
        numberOfLines={1}
        style={styles.cardTitle}
      >
        {title}
      </Text>

      <Text style={styles.cardDetail}>
        ◉ {detail}
      </Text>
    </Pressable>
  );
}

/* =========================================================
   HOME
   ========================================================= */

function Home({ onLogout }) {
  const [search, setSearch] = useState('');
  const [budget, setBudget] = useState('all');
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [places, setPlaces] = useState([]);
  const [loadingPlaces, setLoadingPlaces] = useState(false);
  const [placesError, setPlacesError] = useState('');
  const [showBusinessForm, setShowBusinessForm] = useState(false);

  const budgetOptions = [
    {
      id: 'premium',
      icon: '💎',
      label: 'Premium',
      description: 'Experiencias exclusivas',
    },
    {
      id: 'medio',
      icon: '💰',
      label: 'Medio',
      description: 'Buena relación precio/experiencia',
    },
    {
      id: 'bajo',
      icon: '🌿',
      label: 'Bajo',
      description: 'Opciones económicas',
    },
  ];

  const loadPlaces = async () => {
    try {
      setLoadingPlaces(true);
      setPlacesError('');

      let query = supabase
        .from('businesses')
        .select(`
          id,
          name,
          description,
          category,
          phone,
          email,
          website,
          image_url,
          address,
          province,
          canton,
          district,
          latitude,
          longitude,
          budget_level
        `);

      if (selectedCategory) {
        const supabaseCategory =
          categoryMap[selectedCategory] || selectedCategory;

        if (selectedCategory === 'Termales') {
          const { data: thermalBusinesses, error: thermalError } =
            await supabase
              .from('business_categories')
              .select('business_id')
              .eq('category', 'Termales');

          if (thermalError) {
            console.log(
              'Error consultando categorías adicionales:',
              thermalError.message
            );

            setPlacesError(
              'No se pudieron cargar las categorías adicionales.'
            );

            setPlaces([]);
            return;
          }

          const thermalIds =
            thermalBusinesses?.map((item) => item.business_id) || [];

          if (thermalIds.length > 0) {
            query = query.or(
              `category.eq.${supabaseCategory},id.in.(${thermalIds.join(',')})`
            );
          } else {
            query = query.eq('category', supabaseCategory);
          }
        } else {
          query = query.eq('category', supabaseCategory);
        }
      }

      if (budget !== 'all') {
        query = query.eq('budget_level', budget);
      }

      query = query.eq('is_active', true);

      const { data, error } = await query.order('name');

      if (error) {
        console.log(
          'Error consultando negocios:',
          error.message
        );

        setPlacesError(
          'No se pudieron cargar los negocios.'
        );

        setPlaces([]);
        return;
      }

      setPlaces(data || []);
    } catch (error) {
      console.log(
        'Error inesperado consultando negocios:',
        error
      );

      setPlacesError(
        'Ocurrió un error al consultar los negocios.'
      );

      setPlaces([]);
    } finally {
      setLoadingPlaces(false);
    }
  };

  useEffect(() => {
    loadPlaces();
  }, [selectedCategory, budget]);

  const filteredPlaces = places.filter((place) => {
    const text = search.trim().toLowerCase();

    if (!text) {
      return true;
    }

    return (
      place.name?.toLowerCase().includes(text) ||
      place.category?.toLowerCase().includes(text) ||
      place.description?.toLowerCase().includes(text) ||
      place.address?.toLowerCase().includes(text) ||
      place.canton?.toLowerCase().includes(text) ||
      place.district?.toLowerCase().includes(text)
    );
  });

  const getBudgetLabel = (value) => {
    if (value === 'premium') {
      return '💎 Premium';
    }

    if (value === 'medio') {
      return '💰 Presupuesto medio';
    }

    if (value === 'bajo') {
      return '🌿 Bajo presupuesto';
    }

    return 'Presupuesto no definido';
  };

  const getPlaceDetail = (place) => {
    const location = [
      place.district,
      place.canton,
      place.province,
    ]
      .filter(Boolean)
      .join(' · ');

    return location || 'Costa Rica';
  };

  const selectBudget = (value) => {
    setBudget((current) =>
      current === value ? 'all' : value
    );
  };

  const selectCategory = (label) => {
    setSelectedCategory((current) =>
      current === label ? null : label
    );
    setSearch('');
  };

  const clearFilters = () => {
    setSearch('');
    setBudget('all');
    setSelectedCategory(null);
  };

  const showPlace = (place) => {
    const location = getPlaceDetail(place);

    Alert.alert(
      place.name || 'Negocio',
      `${place.description || location}\n\n` +
        `Categoría: ${place.category || 'Sin categoría'}\n` +
        `Presupuesto: ${getBudgetLabel(place.budget_level)}\n\n` +
        `Próximamente: ficha completa, reseñas, ubicación y cómo llegar.`
    );
  };

  return showBusinessForm ? (
    <BusinessForm
      onClose={() => setShowBusinessForm(false)}
      onBusinessRegistered={loadPlaces}
    />
  ) : (
    <SafeAreaView style={styles.home}>
      <ScrollView
        contentContainerStyle={styles.homeScroll}
        showsVerticalScrollIndicator={false}
      >
       {/* ENCABEZADO */}
<View style={styles.homeHero}>
  <View style={styles.locationRow}>
    <View style={styles.locationBlock}>
      <Text style={styles.locationCaption}>
        📍  ESTÁS EXPLORANDO
      </Text>

      <Text style={styles.location}>
        La Fortuna, San Carlos
      </Text>
    </View>

    <View style={styles.homeLogo}>
      <Text style={styles.homeLogoText}>P</Text>
    </View>
  </View>

  {onLogout ? (
    <Pressable
      onPress={onLogout}
      style={styles.logoutButton}
    >
      <Text style={styles.logoutButtonText}>
        Cerrar sesión
      </Text>
    </Pressable>
  ) : null}

  <Text style={styles.homeTitle}>
    Tu aventura comienza aquí
  </Text>

  <Text style={styles.homeSubtitle}>
    Descubre qué hacer, dónde ir y cómo disfrutar La Fortuna según tu estilo y presupuesto.
  </Text>
</View>

        {/* BUSCADOR */}
        <View style={styles.searchContainer}>
          <Text style={styles.searchIcon}>⌕</Text>

          <TextInput
            value={search}
            onChangeText={setSearch}
            style={styles.searchInput}
            placeholder="¿Qué quieres descubrir? Ej. termales, hotel, tour..."
            placeholderTextColor={colors.muted}
            autoCapitalize="none"
            autoCorrect={false}
          />

          {!!search && (
            <Pressable
              onPress={() => setSearch('')}
              style={styles.searchClear}
            >
              <Text style={styles.searchClearText}>×</Text>
            </Pressable>
          )}
        </View>

        {/* PRESUPUESTO */}
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.section}>
              ELIGE TU PRESUPUESTO
            </Text>

            <Text style={styles.sectionHint}>
              Encuentra opciones según lo que quieres gastar
            </Text>
          </View>
        </View>

        <View style={styles.budgetRow}>
          {budgetOptions.map((option) => {
            const active = budget === option.id;

            return (
              <Pressable
                key={option.id}
                onPress={() => selectBudget(option.id)}
                style={[
                  styles.budgetButton,
                  active && styles.budgetButtonActive,
                ]}
              >
                <Text style={styles.budgetIcon}>
                  {option.icon}
                </Text>

                <Text
                  style={[
                    styles.budgetText,
                    active && styles.budgetTextActive,
                  ]}
                >
                  {option.label}
                </Text>

                <Text
                  style={[
                    styles.budgetDescription,
                    active && styles.budgetDescriptionActive,
                  ]}
                  numberOfLines={2}
                >
                  {option.description}
                </Text>
              </Pressable>
            );
          })}
        </View>

        {/* CATEGORÍAS */}
        {categoryGroups.map((group) => (
          <View
            key={group.title}
            style={styles.categoryGroup}
          >
            <Text style={styles.section}>
              {group.title.toUpperCase()}
            </Text>

            <View style={styles.grid}>
              {group.categories.map(
                ([icon, label]) => {
                  const active =
                    selectedCategory === label;

                  return (
                    <Pressable
                      key={label}
                      onPress={() => selectCategory(label)}
                      style={[
                        styles.category,
                        active && styles.categoryActive,
                      ]}
                    >
                      <Text style={styles.categoryIcon}>
                        {icon}
                      </Text>

                      <Text
                        style={[
                          styles.categoryText,
                          active && styles.categoryTextActive,
                        ]}
                      >
                        {label}
                      </Text>
                    </Pressable>
                  );
                }
              )}
            </View>
          </View>
        ))}

        {/* REGISTRAR NEGOCIO */}
        <Pressable
          onPress={() => setShowBusinessForm(true)}
          style={styles.registerBusinessButton}
        >
          <View style={styles.registerBusinessIconCircle}>
            <Text style={styles.registerBusinessIcon}>
              +
            </Text>
          </View>

          <View style={styles.registerBusinessContent}>
            <Text style={styles.registerBusinessTitle}>
              ¿Tienes un negocio?
            </Text>

            <Text style={styles.registerBusinessText}>
              Regístralo y haz que aparezca en Pura Ruta Guide.
            </Text>
          </View>

          <Text style={styles.registerBusinessArrow}>
            ›
          </Text>
        </Pressable>

        {/* OPCIONES PARA TI */}
        <View style={styles.resultsHeader}>
          <View style={styles.resultsHeaderContent}>
            <Text style={styles.section}>
              ✨ OPCIONES PARA TI
            </Text>

            {loadingPlaces ? (
              <Text style={styles.resultSummary}>
                Buscando experiencias...
              </Text>
            ) : (
              <Text style={styles.resultSummary}>
                {filteredPlaces.length === 0
                  ? 'Explora nuestras opciones'
                  : `${filteredPlaces.length} ${
                      filteredPlaces.length === 1
                        ? 'opción encontrada'
                        : 'opciones encontradas'
                    }`}
              </Text>
            )}

            {(selectedCategory || budget !== 'all') && (
              <Text style={styles.activeFilters}>
                {selectedCategory
                  ? `Categoría: ${selectedCategory}`
                  : 'Todas las categorías'}
                {' · '}
                {budget === 'all'
                  ? 'Todos los presupuestos'
                  : getBudgetLabel(budget)}
              </Text>
            )}
          </View>

          {(selectedCategory ||
            budget !== 'all' ||
            search.trim()) && (
            <Pressable
              onPress={clearFilters}
              style={styles.clearButton}
            >
              <Text style={styles.clearButtonText}>
                Limpiar
              </Text>
            </Pressable>
          )}
        </View>

        {/* RESULTADOS */}
        <View style={styles.resultsList}>
          {loadingPlaces ? (
            <View style={styles.noResults}>
              <Text style={styles.noResultsIcon}>
                🔎
              </Text>

              <Text style={styles.noResultsTitle}>
                Buscando opciones...
              </Text>

              <Text style={styles.noResultsText}>
                Estamos consultando los negocios disponibles
                en Pura Ruta.
              </Text>
            </View>
          ) : placesError ? (
            <View style={styles.noResults}>
              <Text style={styles.noResultsIcon}>
                ⚠️
              </Text>

              <Text style={styles.noResultsTitle}>
                No se pudo realizar la búsqueda
              </Text>

              <Text style={styles.noResultsText}>
                {placesError}
              </Text>

              <Pressable
                onPress={loadPlaces}
                style={styles.noResultsButton}
              >
                <Text style={styles.noResultsButtonText}>
                  Intentar nuevamente
                </Text>
              </Pressable>
            </View>
          ) : filteredPlaces.length === 0 ? (
            <View style={styles.noResults}>
              <Text style={styles.noResultsIcon}>
                🌿
              </Text>

              <Text style={styles.noResultsTitle}>
                Explora La Fortuna
              </Text>

              <Text style={styles.noResultsText}>
                {selectedCategory || budget !== 'all' || search.trim()
                  ? 'No hay resultados con esos filtros. Prueba otra categoría o presupuesto.'
                  : 'Selecciona un presupuesto o una categoría para descubrir las opciones disponibles.'}
              </Text>
            </View>
          ) : (
            filteredPlaces.map((place) => (
              <Pressable
                key={place.id}
                onPress={() => showPlace(place)}
                style={styles.resultCard}
              >
                <ImageBackground
                  source={
                    place.image_url
                      ? { uri: place.image_url }
                      : { uri: hero }
                  }
                  style={styles.resultImage}
                >
                  <Text style={styles.cardLabel}>
                    {place.category || 'Lugar'}
                  </Text>
                </ImageBackground>

                <View style={styles.resultContent}>
                  <Text
                    numberOfLines={2}
                    style={styles.resultTitle}
                  >
                    {place.name}
                  </Text>

                  <Text
                    numberOfLines={1}
                    style={styles.cardDetail}
                  >
                    📍 {getPlaceDetail(place)}
                  </Text>

                  <Text style={styles.resultBudget}>
                    {getBudgetLabel(place.budget_level)}
                  </Text>
                </View>

                <Text style={styles.resultArrow}>
                  ›
                </Text>
              </Pressable>
            ))
          )}
        </View>

        {/* PLANIFICADOR */}
        <View style={styles.plannerCard}>
          <View style={styles.plannerIconCircle}>
            <Text style={styles.plannerIcon}>
              🧭
            </Text>
          </View>

          <View style={styles.plannerContent}>
            <Text style={styles.plannerTitle}>
              Planifica tu viaje
            </Text>

            <Text style={styles.plannerText}>
              Próximamente podrás crear un itinerario
              personalizado según tu presupuesto,
              tiempo y preferencias.
            </Text>

            <Text style={styles.plannerComingSoon}>
              PRÓXIMAMENTE
            </Text>
          </View>
        </View>

        {/* MAPA */}
        <Text style={styles.section}>
          MAPA DE AVENTURAS
        </Text>

        <Pressable
          onPress={() =>
            Alert.alert(
              'Mapa de aventuras',
              'Próximamente podrás explorar rutas, volcanes, cataratas y aguas termales.'
            )
          }
          style={styles.map}
        >
          <View style={styles.mapOverlay}>
            <Text style={styles.mapTitle}>
              LA FORTUNA · COSTA RICA
            </Text>

            <Text style={styles.mapText}>
              🌋  Volcán Arenal{`\n`}
              ♨️  Aguas termales{`\n`}
              💧  Cataratas
            </Text>

            <Text style={styles.mapButton}>
              Explorar mapa  ›
            </Text>
          </View>
        </Pressable>

        {/* CERCA DE TI */}
        <View style={styles.nearbyHeader}>
          <View>
            <Text style={styles.section}>
              CERCA DE TI
            </Text>

            <Text style={styles.sectionHint}>
              Lugares destacados en La Fortuna
            </Text>
          </View>

          <Pressable
            onPress={() =>
              Alert.alert(
                'Cerca de ti',
                'Próximamente podrás explorar lugares según tu ubicación.'
              )
            }
          >
            <Text style={styles.viewAll}>
              Ver todo ›
            </Text>
          </Pressable>
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.cards}
        >
          <PlaceCard
            image={hotSprings}
            label="Termales"
            title="Tabacón Hot Springs"
            detail="A 2.3 km de ti · ★ 4.8"
          />

          <PlaceCard
            image={arenal}
            label="Hospedaje"
            title="Arenal Observatory"
            detail="A 5.1 km de ti"
          />
        </ScrollView>

        {/* PIE */}
        <View style={styles.homeFooter}>
          <Text style={styles.homeFooterBrand}>
            PURA RUTA GUIDE
          </Text>

          <Text style={styles.homeFooterText}>
            Explora · Descubre · Vive Costa Rica
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function BusinessForm({ onClose, onBusinessRegistered }) {
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [description, setDescription] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [website, setWebsite] = useState('');
  const [province, setProvince] = useState('');
  const [canton, setCanton] = useState('');
  const [district, setDistrict] = useState('');
  const [address, setAddress] = useState('');
  const [businessBudget, setBusinessBudget] = useState('medio');
  const [businessPhoto, setBusinessPhoto] = useState(null);
  const [savingBusiness, setSavingBusiness] = useState(false);

  const pickBusinessPhoto = async () => {
    try {
      console.log('=== SELECCIONANDO FOTOGRAFIA ===');

      const permission =
        await ImagePicker.requestMediaLibraryPermissionsAsync();

      console.log(
        'Permiso galeria:',
        permission.status
      );

      if (
        permission.status !== 'granted' &&
        permission.status !== 'limited'
      ) {
        Alert.alert(
          'Permiso requerido',
          'Necesitamos acceso a tus fotografias para seleccionar una imagen del negocio.'
        );
        return;
      }

      const result =
        await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ['images'],
          allowsEditing: true,
          aspect: [16, 9],
          quality: 0.8,
        });

      console.log(
        'Resultado selector:',
        result
      );

      if (
        result.canceled ||
        !result.assets ||
        result.assets.length === 0
      ) {
        console.log(
          'Seleccion de fotografia cancelada.'
        );
        return;
      }

      const selectedUri =
        result.assets[0].uri;

      console.log(
        'Fotografia seleccionada:',
        selectedUri
      );

      setBusinessPhoto(selectedUri);

    } catch (error) {
      console.log(
        'Error seleccionando fotografia:',
        error
      );

      Alert.alert(
        'Error',
        'No fue posible seleccionar la fotografia.'
      );
    }
  };

  const submitBusiness = async () => {
    if (!name.trim()) {
      Alert.alert(
        'Informaci\u00F3n requerida',
        'Por favor indica el nombre del negocio.'
      );
      return;
    }

    if (!category) {
      Alert.alert(
        'Informaci\u00F3n requerida',
        'Por favor selecciona una categor\u00EDa.'
      );
      return;
    }

    try {
      setSavingBusiness(true);

      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (userError) {
        console.log(
          'Error obteniendo usuario:',
          userError.message
        );

        Alert.alert(
          'Error',
          'No fue posible identificar al usuario actual.'
        );

        return;
      }

      if (!user) {
        Alert.alert(
          'Sesi\u00F3n requerida',
          'Debes iniciar sesi\u00F3n para registrar un negocio.'
        );

        return;
      }

      let imageUrl = null;

      if (businessPhoto) {
        try {
          console.log('=== SUBIENDO FOTOGRAFIA DEL NEGOCIO ===');

          imageUrl = await uploadBusinessPhoto(
            user.id,
            businessPhoto
          );

          console.log(
            'Fotografia subida correctamente:',
            imageUrl
          );
        } catch (photoError) {
          console.log(
            'Error subiendo fotografia:',
            photoError
          );

          Alert.alert(
            'No se pudo subir la fotograf\u00EDa',
            photoError?.message ||
              'No fue posible subir la fotograf\u00EDa seleccionada.'
          );

          return;
        }
      }

      const { error } = await supabase
        .from('businesses')
        .insert({
          owner_id: user.id,
          name: name.trim(),
          description: description.trim() || null,
          category,
          phone: phone.trim() || null,
          email: email.trim() || null,
          website: website.trim() || null,
          image_url: imageUrl,
          province: province.trim() || null,
          canton: canton.trim() || null,
          district: district.trim() || null,
          address: address.trim() || null,
          budget_level: businessBudget,
          is_active: true,
          is_verified: false,
        });

      if (error) {
        console.log(
          'Error registrando negocio:',
          error.message
        );

        Alert.alert(
          'No se pudo registrar',
          error.message ||
            'Ocurri\u00F3 un error al registrar el negocio.'
        );

        return;
      }

      Alert.alert(
        '\u00A1Negocio registrado!',
        'Tu negocio fue registrado correctamente en Pura Ruta Guide.',
        [
          {
            text: 'Aceptar',
            onPress: () => {
              onClose();

              if (onBusinessRegistered) {
                onBusinessRegistered();
              }
            },
          },
        ]
      );
    } catch (error) {
      console.log(
        'Error inesperado registrando negocio:',
        error
      );

      Alert.alert(
        'Error',
        'Ocurri\u00F3 un error inesperado al registrar el negocio.'
      );
    } finally {
      setSavingBusiness(false);
    }
  };

  return (
    <SafeAreaView style={styles.businessFormScreen}>
      <ScrollView
        contentContainerStyle={styles.businessFormScroll}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.businessFormHeader}>
          <Pressable
            onPress={onClose}
            style={styles.businessFormBack}
          >
            <Text style={styles.businessFormBackText}>‹</Text>
          </Pressable>

          <View style={styles.businessFormHeaderText}>
            <Text style={styles.businessFormTitle}>
              Registra tu negocio
            </Text>

            <Text style={styles.businessFormSubtitle}>
              Haz que tu negocio aparezca en Pura Ruta Guide
            </Text>
          </View>
        </View>

        <Text style={styles.businessFormSection}>
          INFORMACIÓN DEL NEGOCIO
        </Text>

        <Text style={styles.businessFormLabel}>
          Nombre del negocio *
        </Text>

        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="Ej. Arenal Adventure"
          placeholderTextColor="#789084"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormLabel}>
          Categoría *
        </Text>

        <View style={styles.businessCategoryGrid}>
          {businessCategories.map((item) => {
            const active = category === item;

            return (
              <Pressable
                key={item}
                onPress={() => setCategory(item)}
                style={[
                  styles.businessCategoryButton,
                  active && styles.businessCategoryButtonActive,
                ]}
              >
                <Text
                  style={[
                    styles.businessCategoryText,
                    active && styles.businessCategoryTextActive,
                  ]}
                >
                  {item}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.businessFormLabel}>
          Descripción
        </Text>

        <TextInput
          value={description}
          onChangeText={setDescription}
          placeholder="Cuéntanos sobre tu negocio..."
          placeholderTextColor="#789084"
          multiline
          numberOfLines={4}
          textAlignVertical="top"
          style={[
            styles.businessFormInput,
            styles.businessFormTextArea,
          ]}
        />

        <Text style={styles.businessFormSection}>
          CONTACTO
        </Text>

        <Text style={styles.businessFormLabel}>
          Teléfono
        </Text>

        <TextInput
          value={phone}
          onChangeText={setPhone}
          placeholder="+506 8888-8888"
          placeholderTextColor="#789084"
          keyboardType="phone-pad"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormLabel}>
          Correo electrónico
        </Text>

        <TextInput
          value={email}
          onChangeText={setEmail}
          placeholder="correo@negocio.com"
          placeholderTextColor="#789084"
          keyboardType="email-address"
          autoCapitalize="none"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormLabel}>
          Sitio web
        </Text>

        <TextInput
          value={website}
          onChangeText={setWebsite}
          placeholder="https://..."
          placeholderTextColor="#789084"
          autoCapitalize="none"
          keyboardType="url"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormSection}>
          UBICACIÓN
        </Text>

        <Text style={styles.businessFormLabel}>
          Provincia
        </Text>

        <TextInput
          value={province}
          onChangeText={setProvince}
          placeholder="Alajuela"
          placeholderTextColor="#789084"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormLabel}>
          Cantón
        </Text>

        <TextInput
          value={canton}
          onChangeText={setCanton}
          placeholder="San Carlos"
          placeholderTextColor="#789084"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormLabel}>
          Distrito
        </Text>

        <TextInput
          value={district}
          onChangeText={setDistrict}
          placeholder="La Fortuna"
          placeholderTextColor="#789084"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormLabel}>
          Dirección
        </Text>

        <TextInput
          value={address}
          onChangeText={setAddress}
          placeholder="Dirección del negocio"
          placeholderTextColor="#789084"
          style={styles.businessFormInput}
        />

        <Text style={styles.businessFormSection}>
          NIVEL DE PRESUPUESTO
        </Text>

        <View style={styles.businessBudgetRow}>
          {[
            ['bajo', '🌿', 'Bajo'],
            ['medio', '💰', 'Medio'],
            ['premium', '💎', 'Premium'],
          ].map(([id, icon, label]) => {
            const active = businessBudget === id;

            return (
              <Pressable
                key={id}
                onPress={() => setBusinessBudget(id)}
                style={[
                  styles.businessBudgetButton,
                  active && styles.businessBudgetButtonActive,
                ]}
              >
                <Text style={styles.businessBudgetIcon}>
                  {icon}
                </Text>

                <Text
                  style={[
                    styles.businessBudgetText,
                    active && styles.businessBudgetTextActive,
                  ]}
                >
                  {label}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <Pressable
          onPress={pickBusinessPhoto}
          style={styles.businessPhotoBox}
        >
          {businessPhoto ? (
            <Image
              source={{ uri: businessPhoto }}
              style={styles.businessPhotoPreview}
              resizeMode="cover"
            />
          ) : (
            <>
              <Text style={styles.businessPhotoIcon}>
                📷
              </Text>

              <Text style={styles.businessPhotoTitle}>
                Fotografía del negocio
              </Text>

              <Text style={styles.businessPhotoText}>
                Toca aquí para seleccionar una fotografía.
              </Text>
            </>
          )}
        </Pressable>

        <Pressable
          onPress={submitBusiness}
          style={styles.businessSubmitButton}
        >
          <Text style={styles.businessSubmitButtonText}>
            REGISTRAR NEGOCIO
          </Text>
        </Pressable>

        <Pressable
          onPress={onClose}
          style={styles.businessCancelButton}
        >
          <Text style={styles.businessCancelButtonText}>
            Cancelar
          </Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

export default function App() {
  const [screen, setScreen] =
    useState('splash');

  return (
    <>
      <StatusBar barStyle="light-content" />

      {screen === 'splash' ? (
        <Splash
          onContinue={() =>
            setScreen('login')
          }
        />
      ) : screen === 'login' ? (
        <Login
          onLogin={() =>
            setScreen('home')
          }
        />
      ) : (
        <Home />
      )}

      <ExpoStatusBar style="light" />
    </>
  );
}

/* =========================================================
   ESTILOS
   ========================================================= */

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    backgroundColor: colors.forest,
  },

  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,35,18,.62)',
  },

  splashContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 24,
  },

  mark: {
    color: colors.gold,
    fontSize: 36,
    marginTop: 24,
  },

  splashCenter: {
    alignItems: 'center',
    width: '100%',
  },

  brand: {
    fontSize: 34,
    lineHeight: 36,
    color: 'white',
    fontWeight: '900',
    textAlign: 'center',
    letterSpacing: 1.5,
  },

  tagline: {
    color: colors.pale,
    marginTop: 14,
    fontSize: 13,
  },

  progressTrack: {
    height: 4,
    backgroundColor: '#12572e',
    borderRadius: 4,
    width: '62%',
    marginTop: 45,
  },

  progress: {
    height: 4,
    width: '60%',
    backgroundColor: colors.gold,
    borderRadius: 4,
  },

  loading: {
    fontSize: 9,
    color: colors.gold,
    fontWeight: '700',
    marginTop: 10,
  },

  languages: {
    flexDirection: 'row',
    gap: 18,
    marginTop: 44,
    alignItems: 'center',
  },

  languageActive: {
    borderWidth: 1,
    borderColor: colors.gold,
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 6,
    color: colors.gold,
    fontSize: 10,
  },

  language: {
    color: colors.pale,
    fontSize: 10,
  },

  footer: {
    color: colors.muted,
    fontSize: 10,
    textAlign: 'center',
    lineHeight: 17,
    marginBottom: 13,
  },

  button: {
    width: '100%',
    backgroundColor: colors.gold,
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 20,
  },

  buttonText: {
    color: '#10200e',
    fontSize: 15,
    fontWeight: '800',
  },

  buttonOutline: {
    backgroundColor: 'transparent',
    borderColor: colors.gold,
    borderWidth: 1,
    padding: 10,
    marginTop: 16,
    width: 150,
  },

  buttonTextOutline: {
    color: colors.gold,
    fontSize: 12,
  },

  loginBg: {
    flex: 1,
  },

  darkOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,23,10,.72)',
  },

  loginWrap: {
    flex: 1,
    padding: 20,
  },

  back: {
    color: 'white',
    fontSize: 42,
    lineHeight: 40,
  },

  loginBody: {
    flex: 1,
    justifyContent: 'center',
  },

  loginTitle: {
    color: 'white',
    fontWeight: '900',
    fontSize: 28,
    lineHeight: 31,
    textAlign: 'center',
  },

  subtitle: {
    color: colors.pale,
    textAlign: 'center',
    fontSize: 12,
    marginTop: 16,
    marginBottom: 28,
  },

  label: {
    color: colors.pale,
    fontSize: 10,
    marginBottom: 7,
    marginTop: 15,
  },

  input: {
    height: 50,
    backgroundColor: 'rgba(0,30,14,.90)',
    borderRadius: 10,
    color: 'white',
    paddingHorizontal: 16,
    fontSize: 13,
  },

  help: {
    color: colors.muted,
    textAlign: 'center',
    fontSize: 11,
    marginTop: 22,
  },

  goldText: {
    color: colors.gold,
    fontWeight: '700',
  },

  home: {
  flex: 1,
  backgroundColor: colors.forest,
},

homeHero: {
  marginBottom: 4,
},

homeTitle: {
  color: colors.gold,
  fontSize: 25,
  lineHeight: 30,
  fontWeight: '900',
  marginTop: 18,
  marginBottom: 7,
},

homeSubtitle: {
  color: colors.pale,
  fontSize: 12,
  lineHeight: 18,
  marginBottom: 4,
},

  homeScroll: {
    padding: 18,
    paddingBottom: 40,
  },

  locationRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },

  locationCaption: {
    color: colors.muted,
    fontSize: 9,
  },

  location: {
    color: 'white',
    fontWeight: '700',
    fontSize: 13,
    marginTop: 3,
  },

  avatar: {
    fontSize: 27,
  },

  search: {
    height: 48,
    marginTop: 14,
    backgroundColor: '#021b0d',
    color: 'white',
    borderRadius: 10,
    paddingHorizontal: 15,
    fontSize: 12,
  },

  /* =========================================================
     BUSCADOR - ESTILO PURA RUTA
     ========================================================= */

  searchContainer: {
    height: 48,
    marginTop: 14,
    backgroundColor: colors.panel,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#0B4425',
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
  },

  searchIcon: {
    color: colors.gold,
    fontSize: 23,
    marginRight: 9,
  },

  searchInput: {
    flex: 1,
    color: colors.pale,
    fontSize: 12,
    paddingVertical: 0,
  },

  searchClear: {
    width: 30,
    height: 30,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 5,
  },

  searchClearText: {
    color: colors.gold,
    fontSize: 23,
    fontWeight: '500',
  },

  sectionHint: {
    color: colors.muted,
    fontSize: 9,
    lineHeight: 14,
    marginTop: -7,
    marginBottom: 10,
  },

  categoryGroup: {
    marginTop: 2,
  },

  section: {
    color: colors.muted,
    fontSize: 10,
    fontWeight: '700',
    marginTop: 28,
    marginBottom: 12,
  },

  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 9,
  },

  category: {
    backgroundColor: '#031e0d',
    borderRadius: 12,
    width: '18%',
    height: 67,
    alignItems: 'center',
    justifyContent: 'center',
  },

  categoryActive: {
    backgroundColor: '#153d20',
    borderColor: colors.gold,
    borderWidth: 2,
  },

  categoryIcon: {
    color: colors.gold,
    fontSize: 20,
  },

  categoryText: {
    color: 'white',
    fontSize: 8,
    marginTop: 5,
    textAlign: 'center',
  },

  categoryTextActive: {
    color: colors.gold,
    fontWeight: '800',
  },

  budgetRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 2,
  },

  budgetButton: {
    flex: 1,
    minHeight: 88,
    backgroundColor: '#031e0d',
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#0b4425',
    paddingHorizontal: 5,
    paddingVertical: 8,
  },

  budgetButtonActive: {
    backgroundColor: '#153d20',
    borderColor: colors.gold,
    borderWidth: 2,
  },

  budgetIcon: {
    fontSize: 23,
    lineHeight: 27,
  },

  budgetText: {
    color: colors.pale,
    fontSize: 10,
    fontWeight: '800',
    marginTop: 4,
    textAlign: 'center',
  },

  budgetTextActive: {
    color: colors.gold,
  },

  budgetDescription: {
    color: colors.muted,
    fontSize: 8,
    lineHeight: 11,
    marginTop: 3,
    textAlign: 'center',
  },

  budgetDescriptionActive: {
    color: colors.pale,
  },

  resultsHeader: {
    marginTop: 4,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
  },

  resultSummary: {
    color: 'white',
    fontSize: 13,
    fontWeight: '800',
    marginTop: -7,
  },

  activeFilters: {
    color: colors.muted,
    fontSize: 9,
    marginTop: 5,
    maxWidth: 270,
  },

  clearButton: {
    borderWidth: 1,
    borderColor: colors.gold,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 7,
    marginBottom: 4,
  },

  clearButtonText: {
    color: colors.gold,
    fontSize: 9,
    fontWeight: '700',
  },

  resultsList: {
    gap: 10,
  },

  noResults: {
    backgroundColor: '#031e0d',
    borderRadius: 12,
    padding: 22,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#0b4425',
  },

  noResultsIcon: {
    fontSize: 28,
  },

  noResultsTitle: {
    color: 'white',
    fontSize: 14,
    fontWeight: '800',
    marginTop: 10,
    textAlign: 'center',
  },

  noResultsText: {
    color: colors.muted,
    fontSize: 10,
    textAlign: 'center',
    marginTop: 7,
    lineHeight: 16,
  },

  noResultsButton: {
    borderWidth: 1,
    borderColor: colors.gold,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginTop: 14,
  },

  noResultsButtonText: {
    color: colors.gold,
    fontSize: 9,
    fontWeight: '700',
  },

  resultCard: {
    flexDirection: 'row',
    width: '100%',
    minHeight: 105,
    backgroundColor: '#031e0d',
    borderRadius: 11,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#0b4425',
  },

  resultImage: {
    width: 105,
    minHeight: 105,
    justifyContent: 'flex-end',
  },

  resultContent: {
    flex: 1,
    padding: 10,
    justifyContent: 'center',
  },

  resultTitle: {
    color: 'white',
    fontWeight: '800',
    fontSize: 13,
  },

  resultBudget: {
    color: colors.gold,
    fontSize: 9,
    fontWeight: '700',
    marginTop: 7,
  },

  map: {
    height: 145,
    borderRadius: 12,
    overflow: 'hidden',
    padding: 12,
    backgroundColor: '#70A847',
    borderWidth: 2,
    borderColor: '#e6d58b',
  },

  mapTitle: {
    alignSelf: 'center',
    backgroundColor: '#f7eaa8',
    color: '#33240a',
    fontSize: 9,
    fontWeight: '800',
    paddingHorizontal: 12,
    borderRadius: 5,
  },

  mapText: {
    marginTop: 22,
    alignSelf: 'center',
    color: 'white',
    fontWeight: '800',
    fontSize: 12,
    lineHeight: 30,
    backgroundColor: 'rgba(0,0,0,.35)',
    paddingHorizontal: 14,
    borderRadius: 10,
  },

  cards: {
    gap: 12,
  },

  card: {
    width: 175,
    backgroundColor: '#031e0d',
    borderRadius: 11,
    overflow: 'hidden',
    paddingBottom: 10,
  },

  cardImage: {
    height: 100,
    justifyContent: 'flex-end',
  },

  cardLabel: {
    alignSelf: 'flex-start',
    backgroundColor: colors.gold,
    color: '#18250e',
    fontSize: 8,
    fontWeight: '800',
    paddingHorizontal: 7,
    paddingVertical: 4,
    borderRadius: 3,
    margin: 7,
  },

  cardTitle: {
    color: 'white',
    fontWeight: '800',
    fontSize: 13,
    marginHorizontal: 9,
    marginTop: 8,
  },

  cardDetail: {
    color: colors.muted,
    fontSize: 9,
    marginHorizontal: 9,
    marginTop: 5,
  },

  /* =========================================================
     BOTON REGISTRAR NEGOCIO
     ========================================================= */

  registerBusinessButton: {
    width: '100%',
    minHeight: 72,
    backgroundColor: '#031e0d',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: colors.gold,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    marginTop: 14,
    marginBottom: 14,
  },

  registerBusinessIcon: {
    fontSize: 24,
    marginRight: 13,
  },

  registerBusinessContent: {
    flex: 1,
  },

  registerBusinessTitle: {
    color: colors.gold,
    fontSize: 14,
    fontWeight: '900',
  },

  registerBusinessText: {
    color: colors.muted,
    fontSize: 10,
    marginTop: 5,
    lineHeight: 15,
  },

  registerBusinessArrow: {
    color: colors.gold,
    fontSize: 30,
    fontWeight: '300',
    marginLeft: 8,
  },

  /* =========================================================
     ESTILOS FORMULARIO REGISTRAR NEGOCIO
     ========================================================= */

  businessFormScreen: {
    flex: 1,
    backgroundColor: colors.forest,
  },

  businessFormScroll: {
    padding: 20,
    paddingBottom: 50,
  },

  businessFormHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 24,
  },

  businessFormBack: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: '#031e0d',
    borderWidth: 1,
    borderColor: '#0b4425',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },

  businessFormBackText: {
    color: colors.gold,
    fontSize: 32,
    lineHeight: 34,
    fontWeight: '300',
  },

  businessFormHeaderText: {
    flex: 1,
  },

  businessFormTitle: {
    color: colors.gold,
    fontSize: 24,
    fontWeight: '900',
    lineHeight: 28,
  },

  businessFormSubtitle: {
    color: colors.gold,
    fontSize: 11,
    marginTop: 5,
    lineHeight: 16,
  },

  businessFormSection: {
    color: colors.gold,
    fontSize: 11,
    fontWeight: '900',
    letterSpacing: 1,
    marginTop: 18,
    marginBottom: 12,
  },

  businessFormLabel: {
    color: colors.pale,
    fontSize: 11,
    fontWeight: '700',
    marginTop: 12,
    marginBottom: 7,
  },

  businessFormInput: {
    width: '100%',
    minHeight: 48,
    backgroundColor: '#031e0d',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#0b4425',
    color: 'white',
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 12,
  },

  businessFormTextArea: {
    minHeight: 105,
    paddingTop: 13,
  },

  businessCategoryGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },

  businessCategoryButton: {
    backgroundColor: '#031e0d',
    borderWidth: 1,
    borderColor: '#0b4425',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minWidth: '30%',
    alignItems: 'center',
    justifyContent: 'center',
  },

  businessCategoryButtonActive: {
    backgroundColor: '#153d20',
    borderColor: colors.gold,
  },

  businessCategoryText: {
    color: colors.pale,
    fontSize: 10,
    fontWeight: '700',
    textAlign: 'center',
  },

  businessCategoryTextActive: {
    color: colors.gold,
    fontWeight: '900',
  },

  businessBudgetRow: {
    flexDirection: 'row',
    gap: 8,
  },

  businessBudgetButton: {
    flex: 1,
    minHeight: 78,
    backgroundColor: '#031e0d',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#0b4425',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 5,
  },

  businessBudgetButtonActive: {
    backgroundColor: '#153d20',
    borderColor: colors.gold,
  },

  businessBudgetIcon: {
    fontSize: 21,
    marginBottom: 4,
  },

  businessBudgetText: {
    color: colors.pale,
    fontSize: 10,
    fontWeight: '700',
  },

  businessBudgetTextActive: {
    color: colors.gold,
    fontWeight: '900',
  },

  businessPhotoPreview: {
    width: '100%',
    height: 180,
    borderRadius: 14,
  },

  businessPhotoBox: {
    marginTop: 20,
    padding: 20,
    minHeight: 145,
    borderRadius: 12,
    backgroundColor: '#031e0d',
    borderWidth: 1,
    borderColor: '#0b4425',
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },

  businessPhotoIcon: {
    fontSize: 30,
    marginBottom: 8,
  },

  businessPhotoTitle: {
    color: 'white',
    fontSize: 13,
    fontWeight: '800',
    textAlign: 'center',
  },

  businessPhotoText: {
    color: colors.muted,
    fontSize: 10,
    textAlign: 'center',
    lineHeight: 15,
    marginTop: 6,
    maxWidth: 280,
  },

  businessSubmitButton: {
    width: '100%',
    backgroundColor: colors.gold,
    borderRadius: 11,
    minHeight: 52,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 24,
    paddingHorizontal: 16,
  },

  businessSubmitButtonText: {
    color: '#10200e',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 0.5,
  },

  businessCancelButton: {
    width: '100%',
    minHeight: 45,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#0b4425',
    backgroundColor: 'transparent',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 10,
  },

  businessCancelButtonText: {
    color: colors.muted,
    fontSize: 11,
    fontWeight: '700',
  },});



















