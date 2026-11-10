# Calorie Tracker AI — Documento Guida, Architettura & Specifiche UI/UX

## 1. Visione del Progetto
Applicazione Android **personale**, nativa e orientata alla privacy, sviluppata in **Flutter** con design system **Material Design 3 / Expressive**.
Permette il tracciamento completo e quotidiano di **Calorie, Macronutrienti (Proteine, Carboidrati, Grassi), Fibre, Acqua e Peso corporeo**, combinando:
- **Motore AI Multi-Provider** (*Google Gemini* + *OpenAI*) per l'analisi da testo/voce e foto con scomposizione degli ingredienti e correzione conversazionale.
- **Scanner Codici a Barre** integrato con *OpenFoodFacts*.
- **Architettura Offline-First a costo zero (0 €/mese)**: Database locale **SQLite** sul telefono con sincronizzazione automatica (e manuale) nella cartella nascosta `appDataFolder` di **Google Drive** tramite **Google Sign-In**.

---

## 2. Stack Tecnologico (Flutter)

| Livello | Pacchetto / Tecnologia | Scopo |
| :--- | :--- | :--- |
| **Framework & UI** | `Flutter` (ARM64 Android) | UI nativa 60/120fps con `useMaterial3: true` (Material 3 Expressive). |
| **Tema Dinamico** | `dynamic_color` | **Material You**: eredita la palette dallo sfondo Android + colori semantici fissi per i nutrienti. |
| **State Management** | `flutter_riverpod` | Stato reattivo per timeline giornaliera, calcoli nutrizionali real-time e stato sync Drive. |
| **Database Locale** | `drift` (o `sqflite`) + `path_provider` | Persistenza SQLite locale in un singolo file `.sqlite`, query reattive via `Stream`. |
| **Auth & Cloud Sync** | `google_sign_in` + `googleapis` (`drive/v3`) | Login con Google e upload/download automatico del DB nella cartella `appDataFolder` di Drive. |
| **AI Multi-Provider** | `google_generative_ai` + `http`/`dio` | Astrazione `AiNutritionService` con supporto a **Google Gemini** (`gemini-2.5-flash`) e **OpenAI** (`gpt-4o-mini`). |
| **Barcode & Camera** | `mobile_scanner` + `image_picker` | Scansione codici a barre EAN-13/EAN-8 (API OpenFoodFacts) e scatto foto piatti/etichette. |
| **Sicurezza Locale** | `flutter_secure_storage` | Salvataggio cifrato (Android Keystore) delle API Key di Gemini e OpenAI. |
| **Grafici & UI Extra** | `fl_chart` | Grafici Material 3 per andamento calorie, macro e trend del peso corporeo. |

---

## 3. Architettura Dati & Cloud Backup (Zero-Cost)

### 3.1 Strategia per Foto e Spazio su Drive
- **Solo dati nutrizionali nel backup Cloud**: Il database `.sqlite` sincronizzato su Google Drive contiene esclusivamente i dati testuali e numerici (leggerissimo: pochi KB/MB anche dopo anni di utilizzo).
- **Foto nella cache locale**: Le foto scattate ai piatti vengono salvate solo nella memoria locale dell'app sul telefono (`ApplicationSupportDirectory/meal_photos/`) per mostrarle nella timeline finché sono presenti sul dispositivo, senza appesantire il backup su Google Drive.

### 3.2 Flusso di Sincronizzazione Google Drive (`appDataFolder`)
1. **Login**: L'utente effettua l'accesso con il proprio account Google concedendo lo scope `https://www.googleapis.com/auth/drive.appdata`.
2. **Auto-Sync con Debounce**:
   - Ogni modifica al database locale (aggiunta/modifica pasto, acqua, peso, obiettivi) avvia un timer di *debounce* (es. 10 secondi).
   - Se il dispositivo è online, l'app esegue un checkpoint WAL di SQLite e carica silenziosamente il file `calorie_tracker.sqlite` su Google Drive sovrascrivendo la versione precedente.
3. **Sync Manuale & Ripristino**:
   - Nella schermata *Profilo & Cloud* sono sempre visibili la data/ora dell'ultimo backup riuscito e i pulsanti **"Esegui Backup ora"** e **"Ripristina da Google Drive"** (con controllo del timestamp per evitare sovrascritture accidentali di dati più recenti).

---

## 4. Schema Database SQLite

### 4.1 `user_profile` (Configurazione & Target)
- `id` (PK)
- **Dati fisici**: `sex`, `birth_year`, `height_cm`, `current_weight_kg`, `activity_level`, `goal_type` (*DEFICIT, MAINTAIN, SURPLUS*)
- **Modalità target**: `is_manual_override` (`bool` — se `false` usa il calcolo guidato Mifflin-St Jeor, se `true` usa i valori manuali)
- **Target giornalieri**:
  - `target_kcal` (`int`)
  - `target_protein_g`, `target_carbs_g`, `target_fat_g`, `target_fiber_g` (`double`)
  - `target_water_ml` (`int`, es. `2500`)
- **Sync & AI**: `last_drive_backup_at` (`datetime`), `preferred_ai_provider` (`GEMINI` | `OPENAI`), `preferred_ai_model` (`string`)

### 4.2 `meal_entries` (Timeline Cronologica dei Pasti)
- `id` (PK, UUID)
- `date` (`YYYY-MM-DD`, indicizzato per query giornaliere istantanee)
- `logged_at` (`HH:mm`, orario del pasto nella timeline, es. `08:30`, `13:15`, `17:00`)
- `title` (es. *"Pranzo post-allenamento"* o generato dall'AI es. *"Pasta al salmone e insalata"*)
- `notes` (testo opzionale)
- `local_photo_path` (path locale opzionale, non caricato su Drive)
- `total_kcal`, `total_protein_g`, `total_carbs_g`, `total_fat_g`, `total_fiber_g` (campi denormalizzati per performance nei grafici)

### 4.3 `meal_items` (Ingredienti / Alimenti del singolo pasto)
- `id` (PK, UUID)
- `meal_id` (FK → `meal_entries.id` ON DELETE CASCADE)
- `name` (es. *"Pasta di semola"*, *"Olio EVO"*)
- `grams` (`double` — peso attuale scelto dall'utente)
- `kcal_per_100g`, `protein_per_100g`, `carbs_per_100g`, `fat_per_100g`, `fiber_per_100g` (`double` — permette allo slider dei grammi di ricalcolare tutto istantaneamente a costo zero!)
- `source` (`AI_TEXT`, `AI_PHOTO`, `BARCODE`, `FAVORITE`, `MANUAL`)
- `barcode` (`string` opzionale, se proveniente da OpenFoodFacts)

### 4.4 `daily_metrics` (Acqua & Peso Giornaliero)
- `date` (PK, `YYYY-MM-DD`)
- `water_ml` (`int`, default `0`)
- `weight_kg` (`double` nullable — registrato se pesato in quel giorno)
- `updated_at` (`datetime`)

### 4.5 `favorite_foods` (Dispensa / Cibi & Pasti Ricorrenti)
- `id` (PK, UUID)
- `name`, `default_grams`
- `kcal_per_100g`, `protein_per_100g`, `carbs_per_100g`, `fat_per_100g`, `fiber_per_100g`
- `barcode` (opzionale)
- `use_count` (`int` — per ordinare automaticamente i cibi che usi più spesso in cima)

---

## 5. Architettura del Motore AI Multi-Provider

### 5.1 Interfaccia Unificata (`AiNutritionService`)
L'app definisce un'interfaccia astratta con due implementazioni selezionabili nelle impostazioni:
1. **`GeminiNutritionProvider`**: Usa le API ufficiali Google Gemini (modello consigliato di default: `gemini-2.5-flash`, con opzione `gemini-2.5-pro`).
2. **`OpenAiNutritionProvider`**: Usa le API OpenAI Chat Completions con Structured Outputs (modello consigliato di default: `gpt-4o-mini`, con opzione `gpt-4o`).

### 5.2 Contratto JSON Strutturato (per Ricalcolo Real-Time)
Sia per l'input testuale/vocale sia per le foto, il prompt di sistema impone al modello di restituire **sia la stima della porzione sia i valori per 100g** di ciascun ingrediente rilevato:

```json
{
  "meal_title": "Petto di pollo con patate al forno",
  "ai_notes": "Ho stimato 1 cucchiaio d'olio (10g) per la cottura delle patate.",
  "items": [
    {
      "name": "Petto di pollo ai ferri",
      "estimated_grams": 180,
      "per_100g": {
        "kcal": 165,
        "protein_g": 31.0,
        "carbs_g": 0.0,
        "fat_g": 3.6,
        "fiber_g": 0.0
      }
    },
    {
      "name": "Patate al forno",
      "estimated_grams": 200,
      "per_100g": {
        "kcal": 93,
        "protein_g": 2.5,
        "carbs_g": 21.0,
        "fat_g": 0.1,
        "fiber_g": 2.2
      }
    },
    {
      "name": "Olio extravergine d'oliva",
      "estimated_grams": 10,
      "per_100g": {
        "kcal": 884,
        "protein_g": 0.0,
        "carbs_g": 0.0,
        "fat_g": 100.0,
        "fiber_g": 0.0
      }
    }
  ]
}
```
> **Perché i valori `per_100g` sono fondamentali?**
> Quando sposti lo slider dei grammi nella schermata di revisione (es. porti il pollo da `180g` a `150g`), l'app ricalcola istantaneamente a 120fps calorie, proteine, carboidrati, grassi e fibre tramite una semplice moltiplicazione locale, senza dover richiamare l'AI!

### 5.3 Funzione "Correggi con AI" (Refinement Conversazionale)
Nella schermata di revisione, sotto gli slider degli ingredienti, è presente una barra rapida **"Correggi con AI"**:
- L'utente può scrivere o dettare: *"La pasta era integrale e non ho messo olio"* oppure *"Aggiungi 30g di parmigiano"*.
- L'app invia a Gemini/OpenAI il JSON attuale + la richiesta di modifica e aggiorna la lista degli ingredienti in 1–2 secondi.

---

## 6. Linee Guida UI/UX — Material Design 3 Expressive

### 6.1 Tema Visivo e Palette Semantica
- **Base Material You**: I colori di superficie (`surface`, `surfaceContainerHigh`, `primaryContainer`) si adattano dinamicamente allo sfondo di Android (sia in Light che in Dark Mode).
- **Colori Semantici Fissi per i Nutrienti** (sempre riconoscibili a colpo d'occhio):
  - **Calorie (Kcal)**: Colore `Primary` dinamico del tema.
  - **Proteine**: Rosso Corallo / Rosa intenso (`#FF6B6B`)
  - **Carboidrati**: Ambra / Oro caldo (`#FFB74D`)
  - **Grassi**: Viola / Indaco morbido (`#BA68C8`)
  - **Fibre**: Verde Salvia / Smeraldo (`#66BB6A`)
  - **Acqua**: Azzurro Ciano (`#29B6F6`)

---

### 6.2 Wireframe delle 4 Schermate Principali

#### A. Schermata 1: **Oggi (Dashboard & Timeline)**
```text
+-------------------------------------------------------+
|  <  Lun 9   [ Mar 10 Nov ]   Mer 11  >    [Cloud OK]  |
+-------------------------------------------------------+
|  HERO CARD (Material 3 Expressive SurfaceContainer)   |
|   +-------------------+   Proteine  [======---] 110/150g
|   |     1.420         |   Carbo     [====-----] 140/220g
|   |  Kcal Rimanenti   |   Grassi    [=======--]  52/65g
|   | (Consumate: 980)  |   Fibre     [===------]  14/30g
|   +-------------------+                               |
+-------------------------------------------------------+
|  MINI-CARD ACQUA            |  MINI-CARD PESO         |
|  💧 1.500 / 2.500 ml        |  ⚖️ 74,2 kg             |
|  [ +250ml ]   [ +500ml ]    |  (-0,3 kg vs 7gg fa)    |
+-------------------------------------------------------+
|  TIMELINE PASTI DI OGGI                               |
|                                                       |
|  08:30 ●── Colazione proteica                380 kcal |
|        │   • Yogurt greco 0% (170g)                   |
|        │   • Fiocchi d'avena (40g) + Miele (10g)      |
|        │                                              |
|  13:15 ●── Pranzo: Pasta al tonno            600 kcal |
|        │   [Miniatura Foto]                           |
|        │   • Pasta integrale (100g)                   |
|        │   • Tonno al naturale (120g) + Olio (10g)    |
|                                                       |
|                    ( + Aggiungi Pasto )               |
+-------------------------------------------------------+
|  [ Oggi ]      [ Statistiche ]   [ Dispensa ] [ Profilo ]
+-------------------------------------------------------+
```

#### B. Modal Bottom Sheet: **Aggiungi / Rivedi Pasto (AI + Barcode)**
Premendo **`( + Aggiungi Pasto )`** si apre il pannello con l'orario preimpostato a *"Adesso"* (modificabile con un tap):

```text
+-------------------------------------------------------+
|  Nuovo Pasto                          🕒 Orario: 20:15|
|  [ ✨ AI Testo/Voce ] [ 📷 Foto ] [ 🏷️ Barcode ] [ ⭐ ]|
+-------------------------------------------------------+
|  Input AI: "200g di salmone al forno e insalata mista"|
|                                        [ Analizza ✨ ] |
+-------------------------------------------------------+
|  REVISIONE INGREDIENTI RILEVATI (615 kcal totali)     |
|                                                       |
|  1. Salmone al forno                        412 kcal  |
|     [--------●---------]  200 g   (P:40g C:0g G:26g)  |
|                                                       |
|  2. Insalata mista                          25 kcal   |
|     [----●-------------]  150 g   (P:2g C:4g G:0g)    |
|                                                       |
|  3. Olio EVO (stimato dall'AI)              178 kcal  |
|     [--●---------------]   20 g   (P:0g C:0g G:20g)   |
|                                                       |
|  💬 Correggi con AI: [ "Solo 10g di olio..."     ] [>]|
|                                                       |
|  [ ] Salva in Dispensa     [ ✅ Salva nella Timeline ] |
+-------------------------------------------------------+
```

#### C. Schermata 2: **Statistiche & Diario**
- Selettore intervallo: **7 giorni / 30 giorni / 90 giorni**.
- **Grafico 1 — Calorie vs Target**: Grafico a barre M3 con linea tratteggiata del target calorico e media settimanale.
- **Grafico 2 — Equilibrio Macronutrienti & Fibre**: Grafico ad anello/barre impilate con le percentuali medie e media delle fibre giornaliere.
- **Grafico 3 — Andamento Peso Corporeo & Idratazione**: Curva smussata del peso con media mobile a 7 giorni (per filtrare le fluttuazioni d'acqua quotidiane).

#### D. Schermata 3: **Dispensa (Preferiti & Ricorrenti)**
- Barra di ricerca istantanea + pulsante **"Scansiona Barcode per aggiungere in dispensa"**.
- Lista dei cibi e dei pasti completi usati più di frequente: un tap li inserisce direttamente nella timeline all'orario corrente.

#### E. Schermata 4: **Profilo, Obiettivi & Cloud**
- **Card Account Google**: Stato connessione, timestamp ultimo salvataggio automatico in `appDataFolder`, pulsanti *"Backup ora"* e *"Ripristina da Drive"*.
- **Card Calcolatore Obiettivi**:
  - Inserimento *Età, Sesso, Altezza, Peso, Attività, Obiettivo (Dimagrimento / Mantenimento / Massa)*.
  - Calcolo automatico di Kcal, Proteine, Carboidrati, Grassi, Fibre e Acqua, con switch **"Personalizza manualmente"** per sovrascrivere qualsiasi valore.
- **Card Motore AI Multi-Provider**:
  - Scelta del provider attivo: **Google Gemini** (`gemini-2.5-flash` / `gemini-2.5-pro`) oppure **OpenAI** (`gpt-4o-mini` / `gpt-4o`).
  - Campi protetti per inserire le rispettive API Key + pulsante *"Testa connessione AI"*.

---

## 7. Roadmap di Sviluppo

1. **Fase 1 — Setup & Database Locale**:
   - Inizializzazione progetto Flutter (`calorie_tracker_ai`) con tema Material 3 Expressive e Dynamic Color.
   - Creazione database SQLite (`drift` o `sqflite`) con le 5 tabelle e repository reattivi.
2. **Fase 2 — UI Core (Oggi, Timeline, Acqua, Peso, Obiettivi)**:
   - Implementazione della Dashboard *Oggi* con Hero Card (Calorie, Macro, Fibre), Mini-Card Acqua/Peso e Timeline cronologica.
   - Calcolatore guidato TDEE/Macro con override manuale.
3. **Fase 3 — Motore AI Multi-Provider & Barcode Scanner**:
   - Integrazione `GeminiNutritionProvider` e `OpenAiNutritionProvider` con JSON schema strutturato (`per_100g`).
   - Bottom Sheet di inserimento con Testo/Voce, Fotocamera, Scanner Barcode (*OpenFoodFacts*), slider dei grammi in tempo reale e barra *"Correggi con AI"*.
4. **Fase 4 — Google Sign-In & Auto-Backup su Google Drive**:
   - Autenticazione OAuth Google, upload/download su `appDataFolder` e sincronizzazione automatica con debounce.
5. **Fase 5 — Statistiche & Rifiniture**:
   - Grafici di andamento settimanale/mensile per Calorie, Macro, Fibre, Acqua e Peso.
