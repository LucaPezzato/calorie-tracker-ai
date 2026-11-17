# Roadmap Funzionalità: Aderenza & Costanza ("Zero Attrito")

> Obiettivo: rendere l'app utilizzabile con costanza anche nei giorni pieni o stanchi, eliminando l'attrito dell'inserimento manuale e qualsiasi meccanismo punitivo.

---

## 1. Modalità "Zero Attrito" per l'inserimento pasti
**File coinvolti**: `lib/screens/add_meal_bottom_sheet.dart`, `lib/screens/today_screen.dart`, `lib/services/ai_nutrition_service.dart`

- **"Racconta la giornata" (1 inserimento multi-pasto)**:
  - Un flusso in cui l'utente scrive o detta una sola frase (es. *"Stamattina cappuccino e brioche, a pranzo pasta al pesto, stasera pizza"*).
  - L'AI spacchetta automaticamente in `Colazione`, `Pranzo`, `Cena` (o `Spuntino`) e salva tutto in un solo colpo.
- **Pasti Preferiti / "Copia da ieri" in 1 tap**:
  - Chip rapidi su `TodayScreen` per copiare la colazione/pranzo di ieri o ripetere in 1 tap 3–4 pasti ricorrenti salvati.
- **Stima rapida senza ingredienti (3 bottoni)**:
  - Per pasti fuori casa o sgarri, poter registrare con 1 tap (`Leggero ~500 kcal`, `Medio ~800 kcal`, `Abbondante ~1200 kcal`) senza dover scomporre gli ingredienti.

---

## 2. Deep-Link diretto dal Widget Android
**File coinvolti**: `lib/services/widget_sync_service.dart`, `lib/main.dart`, configurazione widget Android

- Aggiungere sul widget home un tasto rapido **"🎤 / 📷 Pasto"** che apra l'app direttamente su `AddMealBottomSheet` già in ascolto vocale o fotocamera (1 tap dalla home invece di 4–5).

---

## 3. Promemoria serale intelligente sui Pasti
**File coinvolti**: `lib/services/water_reminder_service.dart` (o nuovo `meal_reminder_service.dart`), `lib/screens/profile_screen.dart`

- Una sola notifica serale discreta (es. ore **21:00**, configurabile) che scatta **solo se oggi risultano registrati 0 o 1 pasto**: *"Giornata piena? Dimmi in 10 secondi cosa hai mangiato oggi"*.
- Se i pasti sono già stati registrati, nessuna notifica.

---

## 4. Statistiche non punitive & Costanza
**File coinvolti**: `lib/screens/stats_screen.dart`, `lib/data/local_database.dart`

- **Obiettivo settimanale flessibile** al posto di streak rigide: es. **5 giorni attivi su 7** (con 2 giorni "jolly" inclusi per weekend o imprevisti).
- **Budget Calorico Settimanale** affiancato a quello giornaliero, così eventuali sgarri giornalieri vengono visti nel contesto della settimana.
- **Peso con curva di trend (media mobile)**: valorizzare 2–3 pesate a settimana mostrando il trend smussato per non demotivare con le oscillazioni giornaliere.

---

## 5. Recovery Mode dopo giorni di pausa
**File coinvolti**: `lib/screens/today_screen.dart`

- Se l'utente non registra nulla per 2–3 giorni, al rientro mostrare un banner leggero di bentornato con un tasto **"Riparti da oggi"** (e opzione opzionale di stima rapida), evitando schermate punitive o senso di colpa per i giorni vuoti.
