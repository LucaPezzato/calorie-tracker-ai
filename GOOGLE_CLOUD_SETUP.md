# Configurazione Google Sign-In, Google Drive (`appDataFolder`) e Gemini API

Questa guida spiega come abilitare gratuitamente (0 €/mese) il **Login con Google**, il **Backup Automatico su Google Drive** e la **API Key di Google Gemini** per la tua app Android personale.

---

## 1. Ottenere l'impronta SHA-1 della tua chiave di Debug Android

Su Android, il login nativo con Google (`google_sign_in`) non richiede password o client secret nel codice: autentica l'app verificando il **Package Name** (`com.pez.calorie_tracker_ai` o `com.example.calorie_tracker_ai`) e l'impronta **SHA-1** del certificato con cui firmi l'APK.

Esegui nel terminale:
```bash
keytool -list -v \
  -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android \
  -keypass android | grep SHA1
```
Copia la stringa `SHA1: AA:BB:CC:...` che appare.

---

## 2. Configurare Google Cloud Console (0 € / Nessuna Carta Richiesta)

1. Vai su [Google Cloud Console](https://console.cloud.google.com/) e crea un nuovo progetto (es. `Calorie Tracker AI Personal`).
2. **Abilita la Google Drive API**:
   - Vai su **API e servizi → Libreria**.
   - Cerca **Google Drive API** e clicca su **Abilita**.
3. **Configura la Schermata Consenso OAuth**:
   - Vai su **API e servizi → Schermata consenso OAuth**.
   - Scegli **Esterno** (Modalità Test) e inserisci la tua email.
   - Nella sezione **Ambiti (Scopes)** aggiungi lo scope non-sensibile/specifico dell'app:
     `.../auth/drive.appdata` (*Visualizzazione e gestione dei dati di configurazione dell'applicazione sul tuo Google Drive*).
   - In **Utenti di test**, aggiungi il tuo indirizzo Gmail personale.
4. **Crea il Client ID OAuth 2.0 per Android**:
   - Vai su **API e servizi → Credenziali → + Crea credenziali → ID client OAuth**.
   - Tipo di applicazione: **Android**.
   - **Nome pacchetto**: `com.example.calorie_tracker_ai` (o quello impostato in `android/app/build.gradle`).
   - **Impronta certificato SHA-1**: incolla l'impronta SHA-1 ottenuta al punto 1.
   - Clicca su **Crea**. Non devi scaricare alcun file JSON: Google abbina automaticamente il tuo APK tramite Package Name + SHA-1!

---

## 3. Ottenere la API Key Gratuita di Google Gemini (o OpenAI)

### Opzione A: Google Gemini (`gemini-2.5-flash` — Consigliato, Free Tier)
1. Vai su [Google AI Studio (aistudio.google.com/apikey)](https://aistudio.google.com/apikey).
2. Clicca su **Create API Key** e copia la chiave (`AIzaSy...`).
3. Nell'app, apri la tab **Profilo & Cloud → Motore AI Multi-Provider**, seleziona **✨ Google Gemini**, tocca il box della chiave e incollala: verrà salvata cifrata nell'**Android Keystore** del telefono.

### Opzione B: OpenAI (`gpt-4o-mini`)
1. Genera una API Key su `platform.openai.com/api-keys` (`sk-proj-...`).
2. Nell'app, seleziona **🧠 OpenAI GPT** nella tab **Profilo & Cloud** e salva la chiave.
