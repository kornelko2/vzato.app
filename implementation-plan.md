# Implementační plán: Vzato (vzato.app)

Vychází ze `specification.md` (revize 6. 11. 2026). Plán říká, v jakém pořadí a jak se funkce postaví, co je v každé fázi hotové a jak se to ověří. Specifikace říká *co*, tento dokument *jak a kdy*.

---

## 0. Rozhodnutí před první řádkou kódu

| Otázka | Rozhodnutí | Důvod |
|---|---|---|
| Xcode / Swift | Xcode 16+, Swift 6 (jazykový režim 6, výchozí izolace `MainActor`) | Jednodušší souběžnost pro aplikaci, která běží skoro celá na hlavním vlákně. |
| Minimum | iOS 17, iPadOS 17, macOS 14 | Interaktivní widgety, `ContentUnavailableView`, moderní SwiftUI. Zvednout jen pokud to bude vyžadovat HealthKit. |
| Projekt | XcodeGen (`project.yml`), `.xcodeproj` se necommituje | Čitelné diffy, žádné konflikty v projektovém souboru. |
| Cíle | `Vzato` (jedna univerzální aplikace: iOS, iPadOS, macOS v jednom targetu), `VzatoTests`, později `VzatoWidgets`; bundle ID `app.vzato` | Jeden kód, jeden target. |
| Závislosti | Žádné | Licence, bezpečnost, jednoduchost buildu. |
| Server | **Žádný**, rozhodnuto 6. 11. 2026 | Vše přes CloudKit a veřejná API. Vývojář nezpracovává data uživatelů; viz specifikace 5.1 a 13. |
| Testy | Swift Testing, Core Data s in‑memory store (`NSInMemoryStoreType`) | Rychlé, bez simulátoru. |
| Lokalizace | `Localizable.xcstrings`, anglické klíče, čeština, slovenština a maďarština překlad | Standard Apple, plurály v katalogu. Primární trh CZ/SK, maďarština pro rodinné testery. |
| Ukládání fotek | atribut `imageData: Binary Data` s „Allows External Storage“ | Core Data je uloží mimo databázi, CloudKit jako přílohu (CKAsset). |
| Licence | **MPL-2.0**, rozhodnuto 6. 11. 2026 | Slučitelná s App Storem, bez CLA, změny souborů zůstávají otevřené. Hlavička MPL v každém zdrojovém souboru. |
| Úložiště | **Core Data** (`NSPersistentCloudKitContainer`), rozhodnuto 6. 11. 2026 | SwiftData neumí CloudKit sdílení (CKShare); ověřeno 11/2026, stále platí. Viz specifikace, kapitoly 10.3 a 13. |
| Rozsah v1 | Fáze 1–3, pak první veřejné vydání | Minimalistická verze; další fáze podle zájmu uživatelů. |
| Profily | Entita `Profile` v modelu od fáze 1, UI jen „Já“ | Pozdější doplnění = migrace. Specifikace, kapitola 12. |

### Struktura repozitáře

```
vzato.app/
  project.yml
  README.md, LICENSE, CONTRIBUTING.md, specification.md, implementation-plan.md
  Vzato/
    App/          VzatoApp, RootView, AppSettings
    Models/       Profile, Medication, Schedule, DoseEvent, MedicationPhoto, enums
    Services/     DoseScheduler, DoseLogger, StockService, ReconciliationService,
                  NotificationService, PhotoStore, CSVExport
    Views/        Today/, History/, Medications/, Photos/, Settings/, Shared/
    Resources/    Localizable.xcstrings, Assets.xcassets
  VzatoWidgets/   (fáze 7)
  VzatoTests/
```

Zásada: `Services` neobsahují SwiftUI a dají se testovat bez UI. `Views` neobsahují logiku, jen volají služby. Služby pracují s jednoduchými strukturami a protokoly, ne přímo s třídami úložiště, aby šlo úložiště vyměnit (specifikace, kapitola 13).

---

## 1. Datový model a jádro logiky

Společné pro všechny fáze, postaví se hned na začátku a dál se jen rozšiřuje.

### Modely (Core Data)

Přesně podle kapitoly 4 specifikace. Model v `Vzato.xcdatamodeld`, třídy `NSManagedObject` generované Xcode (codegen „Class Definition“), vlastní logika v rozšířeních. Kontejner `NSPersistentCloudKitContainer`; ve fázi 1 bez CloudKit entitlementu (chová se jako běžný `NSPersistentContainer`), ve fázi 6 se jen zapne. Pravidla, která se dodržují od začátku kvůli CloudKitu a budoucímu sdílení:

- Každý atribut má výchozí hodnotu nebo je volitelný. Žádné unikátní constrainty.
- Vztahy jsou volitelné a mají inverzi; `Delete Rule: Cascade` z léku na plány, záznamy a fotografie, z profilu na léky.
- Enumy se ukládají jako `String` (`statusRaw`), přístup přes vypočtenou vlastnost v rozšíření.
- Pole (dny v týdnu, časy) jako `Transformable` s `NSSecureUnarchiveFromDataTransformer`, nebo jako řetězec „1,2,3“; druhé je jednodušší na ladění i pro CloudKit.
- Zápis vždy přes `viewContext` na hlavním vláknu nebo přes `performBackgroundTask`; služby dostávají `NSManagedObjectContext` jako parametr.
- Verze modelu od začátku číslovat (`Vzato 1`), lehká migrace zapnutá.

### Dopočítávání dávek (`DoseScheduler`)

Klíčové rozhodnutí: **záznam `DoseEvent` vzniká až při akci uživatele.** Přehled dneška, kalendář i kontrola zásob pracují s „sloty“:

```
DoseSlot
  medication, scheduledAt, event: DoseEvent?
  status(now, grace) -> pending | taken | skipped | missed
```

- `slots(for: [Medication], on: Date)` – projde plány, vygeneruje časy pro daný den, spáruje s existujícími záznamy (stejný lék, stejná minuta), přidá dávky mimo plán.
- `slots(for:in: DateInterval)` – totéž přes více dní (kalendář, kontrola zásob).
- Slot bez záznamu je `pending`; po uplynutí lhůty (`missedAfterMinutes`, výchozí 120) je `missed`.
- Respektuje `startDate`, `endDate`, `isPaused`, `archivedAt`, dny v týdnu.
- Časy se počítají přes `Calendar` a `startOfDay`, nikdy ručním přičítáním sekund (změna času).

### Záznam akce (`DoseLogger`)

- `markTaken(slot, at:, source:)`, `markSkipped`, `reset` (smaže záznam), `logExtraDose(medication, at:)`.
- Přechod *do* `taken` odečte `unitsPerDose` ze zásoby, přechod *ze* `taken` ji vrátí. Jediné místo, kde se zásoba mění kvůli dávce.
- Po každé změně zavolá kontrolu nízké zásoby.

### Zásoba (`StockService`)

- `setStock(medication, count, at:)` – nastaví `stockCount`, `stockAtLastCount`, `stockCountedAt`, vynuluje `lowStockNotifiedAt`, pokud je zásoba nad hranicí.
- `checkLowStock` – pod hranicí a ještě neoznámeno → notifikace + `lowStockNotifiedAt = now`.
- `projectedRunOutDate` – simuluje budoucí sloty den po dni (max. 365), vrátí čas první dávky, na kterou nezbude dost kusů. `nil` = nedojde v horizontu nebo není plán.

### Kontrola zásob (`ReconciliationService`)

- `report(for medication, actualStock: Int?)` od `stockCountedAt` (jinak `createdAt`) do teď:
  naplánováno, zaznamenáno vzato, přeskočeno, bez záznamu, očekávaná zásoba.
- Výsledek: `consistent`, `unrecordedDoses(n)` (chybí kusy), `overRecordedDoses(n)` (přebývají), `needsCount`.
- `apply(report, actualStock, recordMissingDoses:)` – volitelně označí nejstarší sloty bez záznamu jako vzaté (zdroj `reconciliation`, `takenAt = scheduledAt`), pak `setStock`.

### Notifikace (`NotificationService`)

- Kategorie `DOSE_REMINDER` s akcemi Vzal jsem / Odložit / Přeskočit, kategorie `LOW_STOCK`.
- `rescheduleAll()` – smaže všechny naplánované `dose|…` požadavky a znovu je vytvoří. Volá se při startu, po každé změně léku/plánu a po potvrzení dávky.
- Plánování: opakující se `UNCalendarNotificationTrigger` (den v týdnu + hodina + minuta). Pokud lék platí všech 7 dní, jeden požadavek bez dne v týdnu. Opakování nepotvrzené dávky (+10, +20 min) se plánuje jako jednorázové požadavky jen pro nejbližších 48 hodin, při potvrzení se zruší. Hlídat limit 64.
- `userInfo`: `medicationID`, `minutesOfDay`. Delegát z toho dopočítá slot a volá `DoseLogger`.
- Delegát implementovat jako `nonisolated` s předáním na `MainActor`; objekty z UserNotifications nejsou `Sendable`.

---

## 2. Fáze

Každá fáze končí buildem, který jde pustit a používat. Nic se neodkládá „na později v rámci fáze“.

**v1 = fáze 1–3.** Po fázi 3 jde aplikace do TestFlightu a pak ven (fáze 9 se dělá už tady v malém: licence, README, zásady soukromí). Fáze 4–8 a volitelné fáze 10–12 následují podle zájmu uživatelů a podle toho, jak se projektu daří. Pořadí mezi nimi se může změnit, závislosti ne: widgety (7) potřebují App Group a hotový model, sdílení (10) potřebuje sync (6).

### Fáze 1 – Prototyp na iPhone (jistota, že dávka byla vzata)

**Stav 6. 11. 2026: fáze 1–3 hotové** (v1): kalendář, export CSV, zásoby, kontrola zásoby, opakování nepotvrzených připomínek, včasné upozornění před dojitím zásoby, 20 unit testů, build pro iOS i macOS, archiv pro TestFlight prošel. Zbývá ověřit notifikace na fyzickém zařízení a doladit Mac/iPad layout (fáze 5).

Cíl: jeden lék, jeden plán, notifikace, přehled dneška, tři jazyky. Jeden univerzální target od začátku; Mac a iPad se jen ověřují, že se spustí, layout se dotahuje ve fázi 5.

Úkoly:
1. `project.yml`, cíle, `.gitignore`, README s upozorněním, že nejde o zdravotnický prostředek.
2. Model `Vzato.xcdatamodeld`: `Profile` (jen výchozí „Já“), `Medication`, `Schedule`, `DoseEvent`; `PersistenceController` s `NSPersistentCloudKitContainer` a in‑memory variantou pro testy a náhledy; `@Environment(\.managedObjectContext)` v `VzatoApp`.
3. `DoseScheduler`, `DoseLogger` (zatím bez zásoby) + unit testy.
4. `NotificationService`: oprávnění, kategorie, `rescheduleAll`, zpracování akcí.
5. Views: `RootView` (TabView: Dnes, Historie, Léky, Nastavení – Historie zatím prázdná), `TodayView` podle směru C: velká karta nejbližší nepotvrzené dávky s obřím tlačítkem „Vzal jsem“, Odložit / Přeskočit, pod ní časová osa dne (`DoseRow`), `MedicationsView`, `MedicationFormView` (název, dávka, barva, dny, časy, začátek/konec), `SettingsView` (jazyk, vzhled, odklad, lhůta pro zmeškáno, oprávnění).
6. `Localizable.xcstrings` s češtinou a slovenštinou pro všechny texty včetně akcí v notifikaci.
7. Dávka mimo plán (tlačítko + v Dnes).

Hotovo, když:
- Notifikace přijde v nastavený čas, akce „Vzal jsem“ z notifikace vytvoří záznam i při zavřené aplikaci.
- Potvrzená dávka ukazuje čas potvrzení, dávka po lhůtě je „Zmeškaná“ a lze ji dodatečně potvrdit.
- Přepnutí jazyka aplikace v Nastavení iOS (čeština, slovenština, angličtina) přepne všechny texty.
- Testy: plán podle dnů v týdnu, start/konec, párování záznamů, stav zmeškáno po lhůtě.

### Fáze 2 – Historie a kalendář

Úkoly:
1. `HistoryView`: vlastní měsíční mřížka (`LazyVGrid`, 7 sloupců, první den podle `Calendar.firstWeekday`), barevný stav dne, výběr dne.
2. Seznam dávek vybraného dne se stejným řádkem jako v Dnes; změna stavu přes swipe / kontextové menu.
3. Měsíční souhrn (vzato / zmeškáno / přeskočeno / %).
4. Historie na detailu léku (posledních 20 záznamů).
5. `CSVExport` + `ShareLink` (iOS i macOS).

Hotovo, když:
- Oprava stavu v minulosti se projeví v kalendáři i v souhrnu.
- Export otevře sdílení s názvem souboru `medremind-history.csv`.
- Testy: souhrn dne, CSV formát (escapování čárek a uvozovek).

### Fáze 3 – Zásoby a kontrola

Úkoly:
1. Pole zásoby ve formuláři léku (zapnout, počet, kusů na dávku, hranice).
2. `StockService` + odečítání v `DoseLogger` + testy (odečtení, vrácení, hranice, jedna notifikace, odhad dojití).
3. Detail léku: karta Zásoba (kusů, dávek, „dojde dne“, štítek Dochází, naposledy spočítáno).
4. Banner Dochází v Dnes, štítek v seznamu léků.
5. Notifikace `LOW_STOCK` a včasné upozornění X dní před dojitím (nastavitelné).
6. `ReconciliationService` + testy (souhlasí / chybí / přebývá, doplnění záznamů).
7. `ReconciliationView` (sheet): přehled od posledního spočítání, zadání kusů, výsledek, přepínač „Doplnit záznamy“, uložení.

Hotovo, když:
- Scénář: 10 kusů, 2 dávky denně, 3 dny bez potvrzování, uživatel napočítá 4 → aplikace nabídne doplnit 3 záznamy, po uložení zásoba 4 a historie opravená.
- Notifikace o docházející zásobě přijde jednou, po doplnění a opětovném poklesu znovu.

### Fáze 4 – Fotografie

**Stav 6. 11. 2026: hotovo** (model verze 2, `PhotoStore` přes ImageIO, fotoaparát a skener VisionKit na iOS, knihovna a import souboru všude, prohlížeč se zoomem, miniatura tablety na kartě Dnes, 5 testů). `InfoPlist.xcstrings` s popisem oprávnění fotoaparátu ve třech jazycích.

Úkoly:
1. Model `MedicationPhoto`, `PhotoStore` (zmenšení na 2000 px, JPEG 0.8, miniatura 200 px v cache).
2. Výběr z knihovny (`PhotosPicker`, všechny platformy), fotoaparát (iOS, `UIImagePickerController` ve `UIViewControllerRepresentable`), import souboru (macOS, `fileImporter`).
3. Skener letáku na iOS (`VNDocumentCameraViewController`, více stránek → více `MedicationPhoto` s `pageIndex`).
4. Detail léku: sekce Fotografie se třemi skupinami (krabička, tableta, leták), přidat / smazat / přeuspořádat stránky.
5. Prohlížeč: celá obrazovka, zoom, listování stránek, VoiceOver popisky.
6. Miniatura tablety v řádku dávky v Dnes.
7. `Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (lokalizované přes `InfoPlist.xcstrings`).

Hotovo, když:
- Leták o 6 stránkách naskenovaný na iPhonu se zobrazí seřazený, celkem pod 3 MB.
- Smazání léku smaže i fotografie (ověřit velikost úložiště).

### Fáze 5 – iPad a Mac

**Stav 6. 11. 2026: hotovo v základu** (`NavigationSplitView` se sidebarem na iPadu a Macu, `TabView` na iPhonu, okno Nastavení na Macu, menu Soubor › Nový lék ⌘N / Dávka navíc ⇧⌘N, menu Přejít ⌘1–⌘3, Return potvrdí dávku na kartě). Zbývá ruční kontrola Dynamic Type a rozměrů na fyzických zařízeních.

Úkoly:
1. `NavigationSplitView` pro široké obrazovky (seznam léků / detail), `TabView` zůstává na iPhone.
2. Mac: menu příkazy (Nový lék ⌘N, Export), klávesové zkratky, `Settings` scéna místo záložky.
3. Vstupy specifické pro platformu: `#if os(iOS)` jen v malých obalech (fotoaparát, otevření Nastavení).
4. Entitlements pro macOS (sandbox).
5. Kontrola Dynamic Type a velikosti tlačítek na všech třech platformách.

Hotovo, když: stejný build běží na iPhone, iPadu (obě orientace) a Macu bez platformních chyb v UI.

### Fáze 6 – Synchronizace (CloudKit)

Úkoly:
1. Entitlements iCloud + CloudKit container, `ModelConfiguration(cloudKitDatabase: .private(...))`.
2. Audit modelu podle pravidel CloudKitu (výchozí hodnoty, volitelné vztahy).
3. Po příchodu změn ze sync: `rescheduleAll()` a zrušení doručených notifikací pro potvrzené dávky.
4. Konflikty: `updatedAt` poslední vyhrává; `taken` má přednost před `skipped`/`missed` (řeší se při čtení, ne přepisováním).
5. Stav sync v Nastavení.
6. Fotografie: ověřit velikost a dobu přenosu, rozhodnout otevřenou otázku 8.

Hotovo, když: dvě zařízení se stejným Apple ID, potvrzení na jednom se do minuty objeví na druhém a notifikace tam zmizí.

### Fáze 7 – Widgety

Úkoly: target `VzatoWidgets`, App Group, sdílený kontejner úložiště, `AppIntent` „Vzal jsem“, widget Dnes (malý/střední), widget zamykací obrazovky, Mac widget. Timeline se přegenerovává po změně, ne periodicky.

### Fáze 8 – HealthKit

Úkoly: ověřit aktuální API pro léky, oprávnění **jen na zápis** (z HealthKit se nikdy nečte do synchronizovaného úložiště, pravidlo App Store), zápis při potvrzení, zpětné smazání při `reset`. Vypnutelné v Nastavení.

### Fáze 9 – Beta a vydání

CONTRIBUTING.md, licence, screenshoty cs/sk/en, **zásady ochrany soukromí** (statická stránka na vzato.app, odkaz v aplikaci i v App Store Connect), **Privacy Nutrition Labels** „Data Not Collected“, TestFlight (vyžaduje účet), popis v App Store s upozorněním, že nejde o zdravotnický prostředek. Podklad: specifikace 5.1.

---

## 3. Lokalizace – jak na to prakticky

- Všechny texty v SwiftUI jako literály (`Text("Taken")`), v kódu `String(localized:)`. Žádné skládání vět z částí.
- Tři překlady (cs, sk, hu) vedle anglického klíče. Slovenština není kopie češtiny: překládat zvlášť. Maďarštinu kontrolovat rodilým mluvčím.
- Klíče s čísly používají formát (`"%lld left"`) a pro češtinu i slovenštinu plurálové varianty v katalogu (`one`, `few`, `many`, `other`); maďarština má jen `one`/`other`. Počty kusů jsou desetinné a formátují se přes `DoseFormatter` (½, ¼), proto jsou v klíčích jako `%@`.
- Při každém PR: build s `SWIFT_EMIT_LOC_STRINGS`, nové klíče ve stavu „new“ musí dostat český překlad, jinak PR neprojde (kontrola skriptem nad JSON katalogu).
- Texty notifikačních akcí se registrují při startu, takže změna jazyka se projeví po restartu aplikace. Přijatelné.
- Datum a čas vždy přes `Text(date, style:)` / `FormatStyle`, nikdy ručně.

## 4. Testování

| Vrstva | Nástroj | Co |
|---|---|---|
| Unit | Swift Testing, Core Data in‑memory store, pevný `Calendar` (Europe/Prague) | scheduler, logger, stock, reconciliation, CSV |
| UI | XCUITest | přidat lék, potvrdit dávku, opravit stav v kalendáři, přidat fotku |
| Ruční | fyzická zařízení | notifikace při Focus a úsporném režimu, sync, přechod přes půlnoc, změna času |

Testovací data: pevné datum (např. pondělí 2. 11. 2026), žádné `Date()` v testech.

## 5. Rizika

| Riziko | Dopad | Opatření |
|---|---|---|
| Limit 64 lokálních notifikací | Léky s mnoha časy a opakováním nedostanou připomínku | Plánovat jen nejbližších 48 h pro opakování, opakující se triggery pro hlavní časy, přeplánovat při každém startu |
| Opakování nepotvrzené dávky bez běhu na pozadí | Opakování nelze zrušit, když uživatel potvrdí na jiném zařízení a sync přijde pozdě | Akceptovat ve v1, popsat v README; přes sync zrušit co nejdřív |
| Swift 6 a `UNUserNotificationCenterDelegate` | Chyby kompilace kvůli `Sendable` | `nonisolated` delegát, předat jen hodnoty (UUID, Int, Date) na `MainActor` |
| Core Data + CloudKit omezení | Nutná změna modelu ve fázi 6 | Pravidla dodržovat od fáze 1; `NSPersistentCloudKitContainer` umí schéma ověřit už lokálně (`initializeCloudKitSchema` v debug buildu) |
| Velikost fotografií v iCloudu | Pomalý sync, kvóta | Zmenšování, otevřená otázka 8 |
| České plurály | Nepřirozené texty | Plurálové varianty v katalogu od fáze 1 |

### Volitelná fáze 10 – Rodinné sdílení (jen pokud se rozhodne)

Podle specifikace, kapitola 10. CloudKit sdílení (CKShare) bez vlastního serveru, profil pečovatele, upozornění na nepotvrzenou dávku přes CloudKit odběr, potvrzení za rodiče se zdrojem `caregiver`, správa přístupu. Předpoklad: úložiště je Core Data (rozhodnutí v kapitole 0). Pracnost srovnatelná s fází 6.

### Volitelná fáze 11 – Databáze léčiv (jen pokud se rozhodne)

Podle specifikace, kapitola 11. Skript nad otevřenými daty SÚKL a ŠÚKL vytvoří offline index (název, síla, forma, balení, ATC, kód, EAN), formulář léku dostane našeptávač, detail léku tlačítko „Stáhnout příbalový leták“ (`/dlp/v1/dokumenty/{kod}/pil`). Bez serveru, síť jen na výslovnou akci.

### Volitelná fáze 12 – Více profilů (děti, domácí zvířata)

Podle specifikace, kapitola 12. Model už profil má; přibude správa profilů v Nastavení, výběr profilu ve formuláři léku, jméno a ikona v řádku dávky, ve velké kartě a v notifikaci, filtr v Dnes a Historii, export per profil. Odhad: menší než fáze 2.

### Volitelná fáze 13 – Předání dat při setkání

Podle specifikace, kapitola 14. Pořadí uvnitř fáze: (1) obrazovka Souhrn pro lékaře + PDF přes `ImageRenderer`/`ShareLink`, (2) formát `.vzato` (JSON, verze schématu) s exportem a importem s náhledem, (3) QR kód z balíčku (komprese, sekvence QR pro delší období, čtečka přes `DataScannerViewController` / AVFoundation), (4) šifrovaný balíček heslem (CryptoKit AES‑GCM), (5) „Poslat denní souhrn“ jako jedno klepnutí a Zkratky. Bez serveru, bez nové závislosti.

### Volitelná fáze 14 – Pomocník pro týdenní dávkovač

Podle specifikace, kapitola 15. Pořadí: (1) `Organizer` + `OrganizerService` (rozložení, časová okna, seskupení dávek, týdenní součet kusů) s testy, (2) výběr rozložení v Nastavení, (3) seskupení a tlačítko „Vzato: ráno“ na Dnes a varianta velké karty, (4) obrazovka Naplnit dávkovač s miniaturami a porovnáním se zásobou, (5) hromadná notifikace po dílech. Žádná migrace dat, žádná závislost.

## 6. Co se rozhodne až po prototypu

- Zda zvednout minimum na iOS 18 / macOS 15 kvůli HealthKit API pro léky.
- Zda opakovat zmeškanou dávku ještě jednou notifikací (otevřená otázka 9).
- Zda fotografie synchronizovat vždy, nebo volitelně (otevřená otázka 8).
