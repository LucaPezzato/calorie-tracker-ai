# Design System — Calorie Tracker AI (Material 3 Expressive)

Questo documento definisce i token visivi, la tipografia, il set di icone, i colori semantici e i componenti **Material Design 3 Expressive** per l'app Flutter.

---

## 1. Filosofia Visiva: Material 3 Expressive + Material You

Il design segue l'evoluzione **Material 3 Expressive**:
- **Tonal Elevation senza ombre pesanti**: La profondità tra sfondo, card secondarie e Hero Card è data da 5 livelli di superficie (`surfaceDim` → `surfaceContainerLowest` → `surfaceContainer` → `surfaceContainerHigh` → `surfaceContainerHighest`).
- **Forme morbide e tattili**: Raggi di curvatura ampi (`20dp`–`28dp`) per le card e forme `StadiumBorder` (pillola completa) per bottoni, chip, indicatori di progresso e slider.
- **Dynamic Color (Material You) + Semantica Fissa**:
  - Lo sfondo e l'accento primario (`primary`, `secondary`, `surfaceContainer`) derivano automaticamente dallo sfondo Android dell'utente tramite `dynamic_color` (con fallback a un elegante tema **Emerald / Sage** `#34D399`).
  - I **5 Nutrienti** usano invece **colori semantici fissi** armonizzati (sia in Light che in Dark Mode), così il cervello associa istantaneamente ogni colore al macronutriente senza mai confondersi.

---

## 2. Palette Colori & Token

### 2.1 Superfici (Esempio Dark Mode — Fallback Seed `#34D399`)
| Token Material 3 | Hex (Dark) | Hex (Light) | Utilizzo nell'App |
| :--- | :--- | :--- | :--- |
| `surfaceDim` / `surface` | `#0F1512` | `#F6FBF8` | Sfondo principale dello `Scaffold`. |
| `surfaceContainerLow` | `#18221E` | `#EEF5F1` | Card della Timeline pasti, Mini-Card Acqua e Peso. |
| `surfaceContainer` | `#1D2722` | `#E6EFEA` | Card singoli ingredienti nel Bottom Sheet, input box. |
| `surfaceContainerHigh` | `#23312B` | `#DCE8E1` | **Hero Card** delle calorie, Modal Bottom Sheet, Chip attivi. |
| `primary` | `#5EEAD4` | `#0D9488` | Anello Kcal, FAB `+ Aggiungi Pasto`, giorno selezionato, CTA. |
| `onPrimary` | `#05291E` | `#FFFFFF` | Testo e icone sopra i pulsanti primari. |

### 2.2 Colori Semantici Fissi per i Nutrienti (`NutrientColors` ThemeExtension)
Implementati tramite una `ThemeExtension<NutrientColors>` custom in Flutter:

| Nutriente | Nome Colore | Hex (Dark Mode) | Hex (Light Mode) | Contenitore / Track |
| :--- | :--- | :--- | :--- | :--- |
| **Proteine** | *Coral Red* | `#FF6B6B` | `#E11D48` | `#FF6B6B` al `16%` opacità |
| **Carboidrati** | *Warm Amber* | `#FBBF24` | `#D97706` | `#FBBF24` al `16%` opacità |
| **Grassi** | *Soft Purple* | `#C084FC` | `#9333EA` | `#C084FC` al `16%` opacità |
| **Fibre** | *Leaf Green* | `#4ADE80` | `#16A34A` | `#4ADE80` al `16%` opacità |
| **Acqua** | *Sky Cyan* | `#38BDF8` | `#0284C7` | `#38BDF8` al `16%` opacità |

---

## 3. Tipografia (Sistema Dual-Font / Triple-Font via `google_fonts`)

Per dare carattere espressivo ai numeri e massima leggibilità alle liste degli ingredienti, utilizziamo tre famiglie Google Fonts complementari:

1. **Font Display & Titoli — `Plus Jakarta Sans`** (oppure `Outfit`):
   - Geometrico, moderno, con curve morbide perfette per Material 3 Expressive.
   - Usato per il contatore Kcal centrale, titoli delle schermate, nomi dei pasti e bottoni.
2. **Font UI & Corpo Testo — `Inter`** (oppure `DM Sans`):
   - Progettato per interfacce dense ad alta leggibilità anche a `11sp`–`14sp`.
   - Usato per i nomi dei singoli ingredienti, le note dell'AI e le etichette.
3. **Font Dati & Grammature — `JetBrains Mono`** (o `Inter` con `FontFeature.tabularFigures()`):
   - Garantisce che i numeri (`180 g`, `370 kcal`, `08:30`, `P: 37g`) abbiano larghezza fissa e **non "ballino"** mentre trascini lo slider dei grammi a 120fps!

### Scala Tipografica e Dimensioni (`sp`)
| Ruolo M3 | Font | Dimensione | Peso | Uso |
| :--- | :--- | :--- | :--- | :--- |
| `displayMedium` | Plus Jakarta Sans | **36–40 sp** | `ExtraBold (800)` | Numero Kcal rimanenti al centro della Hero Card. |
| `headlineSmall` | Plus Jakarta Sans | **22 sp** | `Bold (700)` | Titolo App Bar (*"Oggi, 10 Nov"*, *"Statistiche"*). |
| `titleMedium` | Plus Jakarta Sans | **16 sp** | `Bold (700)` | Titolo del pasto nella Timeline, header delle sezioni. |
| `bodyMedium` | Inter | **14 sp** | `Medium (500)` | Singoli ingredienti, testo inserito nel prompt AI. |
| `labelLarge` | Plus Jakarta Sans | **14 sp** | `Bold (700)` | Testo dentro Bottoni, FAB e SegmentedButton. |
| `labelMedium` | JetBrains Mono | **11–12 sp** | `SemiBold (600)` | Orari timeline (`08:30`), badge grammi (`180 g`), riepilogo macro (`P:37g C:0g`). |

---

## 4. Iconografia (Set Icone)

- **Pacchetto consigliato**: **`material_symbols_icons`** (variante **Rounded**, `weight: 500`, `opticalSize: 24dp`) oppure **`lucide_icons_flutter`**.
- **Comportamento dinamico M3**:
  - Nella `NavigationBar` in basso: icona **Outlined (`fill: 0`)** quando il tab è inattivo, icona **Filled (`fill: 1`)** quando il tab è selezionato.
- **Dimensioni standard**:
  - `18dp`: Icone inline nei badge (orologio `20:15`, goccia acqua, nuvola sync Drive).
  - `24dp`: Icone standard della `NavigationBar`, del `SegmentedButton` e del FAB.
  - `28dp`: Icone principali negli stati vuoti o nelle card del profilo.

---

## 5. Spaziature, Raggi di Curvatura e Componenti

### 5.1 Griglia di Spaziatura (Base `4dp` / `8dp`)
- Padding laterale schermata: **`16dp`** (o `20dp` su schermi grandi).
- Spazio verticale tra card principali: **`12dp`**.
- Padding interno delle Card: **`16dp`** (`20dp` per la Hero Card).
- Altezza minima target touch (accessibilità Android): **`48x48dp`**.

### 5.2 Raggi di Curvatura (`BorderRadius`)
- **Hero Card & Modal Bottom Sheet**: `28dp` (`BorderRadius.circular(28)`).
- **Card Timeline Pasti, Mini-Card Acqua/Peso, Card Ingredienti**: `20dp` (`BorderRadius.circular(20)`).
- **Selettore Giorno attivo**: `16dp`.
- **Bottoni, FAB, Chip `+250ml`, Barre di Progresso e Slider**: `StadiumBorder` (`999dp` — pillola completa).
