# Specifikace: MedRemind (pracovní název)

Jednoduchá, zdarma a open source aplikace na připomínání léků pro iPhone, iPad a Mac. Jeden kódový základ, jedna aplikace pro všechna zařízení, data se synchronizují mezi zařízeními uživatele.

Stav: návrh v1, k 6. 11. 2026. Druhá revize: přidáno potvrzování dávek, historie a kalendář, zásoby a jejich kontrola, fotografie léku a příbalového letáku, čeština a angličtina od začátku.

---

## 1. Cíle

- Připomínat léky v nastavených časech a zaznamenat, zda byla dávka vzata.
- Nedopustit, aby uživatel na dávku zapomněl, a dát mu jistotu, že ji už vzal. Zapomenutí nebo dvojí dávka je největší riziko, kterému aplikace předchází.
- Vést historii užitých dávek s kalendářem.
- Hlídat zásobu léků doma a včas upozornit, že dochází.
- Umožnit uložit fotografie léku, tablety a příbalového letáku, aby je měl uživatel vždy po ruce.
- Běžet na iPhone, iPadu a Macu z jednoho zdrojového kódu (SwiftUI, multiplatform).
- Synchronizovat data mezi zařízeními přihlášeného uživatele bez vlastního serveru.
- Zobrazit dnešní dávky na ploše pomocí widgetů.
- Zapisovat užité dávky do Apple Health.
- Zůstat zdarma, bez reklam, bez sledování a bez předplatného.
- Čeština a angličtina od první verze.

### Mimo rozsah (v1)

- Doporučování dávek nebo lékové interakce. Aplikace nenahrazuje lékaře ani lékárníka.
- Účty, vlastní server, sdílení mezi více uživateli (rodina, pečovatelé).
- Android, web, Apple Watch (lze přidat později).
- Rozpoznávání textu (OCR) z krabiček a letáků. Fotografie se jen ukládají a zobrazují.

## 2. Platformy a technologie

| Oblast | Volba | Poznámka |
|---|---|---|
| Platformy | iOS 17+, iPadOS 17+, macOS 14+ | Minimum kvůli interaktivním widgetům (iOS 17) a SwiftData. Upřesnit po prototypu. |
| UI | SwiftUI, jeden multiplatform target | Mac a iPad používají stejné views s adaptivním layoutem. Žádný Catalyst. |
| Data | SwiftData | Lokální úložiště. |
| Sync | SwiftData + CloudKit (privátní databáze) | Data patří uživateli v jeho iCloudu. Vývojář nemá server ani přístup k datům. Zdarma v rámci limitů iCloudu. |
| Notifikace | UserNotifications | Lokální notifikace, bez push serveru. |
| Fotografie | PhotosUI (výběr), AVFoundation / UIImagePickerController (fotoaparát), VisionKit (skenování letáku, jen iOS) | Fotografie se ukládají zmenšené, mimo knihovnu fotek uživatele. |
| Widgety | WidgetKit + App Intents | Stejný kód pro všechny platformy, interaktivní tlačítko „vzal jsem“ na iOS 17+ a macOS 14+. |
| Zdraví | HealthKit | Zápis užitých dávek. Ověřit aktuální API pro léky v dokumentaci Apple před implementací. |
| Jazyk | Swift | Minimální závislosti (ideálně žádné). |
| Lokalizace | String Catalog (`.xcstrings`) | Angličtina jako zdrojový jazyk, čeština jako překlad. |

## 3. Funkce

### 3.1 Léky a plán

- Přidání léku: název, dávka (volný text, např. „500 mg“), počet kusů na dávku (výchozí 1), barva/ikona, poznámka.
- Plán: dny v týdnu, časy (více za den), volitelně „s jídlem / před jídlem / po jídle / bez ohledu“.
- Začátek a konec léčby (volitelně), pauza.
- Jednorázová dávka mimo plán (např. lék na bolest), zaznamená se do historie a odečte ze zásoby.
- Archivace léku: lék zmizí z dnešního přehledu, historie zůstane.
- Fotografie léku, viz 3.7.

### 3.2 Připomínky

- Lokální notifikace v nastavený čas na všech zařízeních uživatele.
- Akce v notifikaci: „Vzal jsem“, „Odložit o 10 minut“, „Přeskočit“.
- Opakování, pokud dávka není potvrzena (nastavitelné, výchozí 2× po 10 minutách). Volitelně stupňování: druhé opakování hlasitější / „Time Sensitive“ (inspirace: eskalační alarmy konkurenční aplikace MedRemind pro Android).
- Tichý režim / Focus: uživatel může povolit „Time Sensitive“ notifikace.
- Notifikace se při potvrzení na jednom zařízení zruší i na ostatních (přes sync).
- Upozornění na docházející zásobu, viz 3.5.

### 3.3 Potvrzení a záznam dávek

Potvrzení „vzal jsem“ je hlavní akce aplikace. Musí být vždy na jedno klepnutí a vždy vidět, co už bylo vzato.

Design: zvolen směr C „Jistota“ (viz `design-options.md`). Obrazovka Dnes má nahoře jednu velkou kartu s nejbližší nebo nejstarší nepotvrzenou dávkou, miniaturou tablety a obřím tlačítkem „Vzal jsem“, pod ní „Odložit“ a „Přeskočit“, a dále celý den jako časovou osu. Ostatní obrazovky jsou systémové seznamy.

- Přehled dneška: seznam dávek rozdělený na „Teď“ (čeká nebo po termínu), „Později“ a „Hotovo“. Stav: čeká / vzato / vynecháno / zmeškáno.
- Velké tlačítko „Vzal jsem“ u každé čekající dávky. Potvrzení lze udělat z aplikace, z notifikace i z widgetu.
- U vzaté dávky je vidět čas potvrzení („Vzato v 8:05“), aby uživatel věděl, že ji nevzal dvakrát.
- Dávka po termínu je označena „Po termínu“ a zůstává nahoře v přehledu, dokud ji uživatel nepotvrdí nebo nepřeskočí.
- Dávka, která není potvrzena ani přeskočena do nastavené lhůty (výchozí 2 hodiny, nastavitelné), se zobrazí jako „Zmeškaná“. Zmeškanou dávku lze dodatečně potvrdit (s původním časem nebo skutečným časem).
- Záznam o dávce vzniká až při akci uživatele. Plánované dávky bez záznamu se dopočítávají z plánu. Díky tomu nehrozí, že by záznamy chyběly po změně plánu nebo po instalaci na nové zařízení.
- Každý záznam má zdroj (aplikace, notifikace, widget, Health, kontrola zásob), aby šlo dohledat, odkud potvrzení přišlo.

### 3.4 Historie a kalendář

- Měsíční kalendář: každý den má barevné označení (vše vzato / něco zmeškáno / nic naplánováno). Dnešek zvýrazněn.
- Klepnutí na den zobrazí jeho dávky se stavem. Stav lze opravit (vzato / vynecháno / zpět na čeká) včetně dnů v minulosti.
- Souhrn za měsíc: počet vzatých, zmeškaných a přeskočených dávek, procento dodržení.
- Historie jednoho léku na jeho detailu (poslední dávky, celkový přehled).
- Export do CSV (lékař, záloha): lék, dávka, plánovaný čas, stav, čas potvrzení, zdroj.
- Archivované léky zůstávají v historii.

### 3.5 Zásoby

- U léku lze zapnout sledování zásoby: počet kusů doma a počet kusů na dávku.
- Každé potvrzení dávky zásobu odečte, zrušení potvrzení ji vrátí. Jednorázová dávka mimo plán se odečítá také.
- Hranice pro upozornění (výchozí 5 kusů). Při poklesu pod hranici: upozornění v aplikaci (banner na přehledu dneška, štítek u léku) a jedna lokální notifikace „Dochází: název, zbývá N“. Další notifikace přijde až po doplnění a opětovném poklesu.
- Odhad, kdy zásoba dojde: z plánu se dopočítá datum první dávky, na kterou už nebude dost kusů. Zobrazuje se na detailu léku („Dojde 24. 11.“) a volitelně jako včasné upozornění (např. 7 dní předem, nastavitelné), aby stihl uživatel zajít pro recept.
- Doplnění zásoby: zadání nového počtu kusů. Datum zadání se uloží jako „naposledy spočítáno“.

### 3.6 Kontrola zásob (odpovídají záznamy skutečnosti?)

Uživatel si občas není jistý, zda lék vzal a jen zapomněl potvrdit, nebo potvrdil a nevzal. Aplikace to umí ověřit podle počtu kusů doma.

- Funkce „Zkontrolovat zásobu“ na detailu léku (a souhrnně v seznamu léků).
- Aplikace ukáže od posledního spočítání: kolik dávek bylo naplánováno, kolik je zaznamenáno jako vzatých, kolik přeskočených, kolik bez záznamu, a kolik kusů by tedy mělo být doma.
- Uživatel spočítá kusy doma a zadá je. Aplikace porovná:
  - **Souhlasí:** záznamy odpovídají skutečnosti.
  - **Chybí kusy:** uživatel vzal více dávek, než zaznamenal. Aplikace nabídne doplnění záznamů: nejstarší dávky bez záznamu (zmeškané) označí jako vzaté se zdrojem „kontrola zásob“.
  - **Přebývají kusy:** uživatel zaznamenal více dávek, než vzal. Aplikace to zobrazí a nechá uživatele záznamy ručně opravit v historii. Automaticky nic neodebírá.
- Po kontrole se uloží nový stav zásoby a datum spočítání. Rozdíl v kusech se přepočítá na dávky podle počtu kusů na dávku.
- Výsledek se nikdy neinterpretuje zdravotně (žádné „vezměte si dávku navíc“). Jen konstatuje rozdíl.

### 3.7 Fotografie léku

- Ke každému léku lze přidat fotografie tří druhů: **krabička** (balení, aby se lék poznal v lékárně i doma), **tableta** (jak vypadá samotná tableta/kapsle, pomůže při pochybnosti „je to ten správný lék?“) a **příbalový leták** (více stránek).
- Zdroj: fotoaparát (iPhone, iPad) nebo výběr z knihovny / souboru (všechny platformy, na Macu hlavně soubor nebo import z iPhonu).
- Příbalový leták: na iOS lze použít skener dokumentů (VisionKit), který narovná a ořízne stránky. Více stránek se ukládá jako seřazená sada fotografií.
- Zobrazení: miniatury na detailu léku, po klepnutí celá obrazovka s přiblížením a listováním stránek letáku. V přehledu dneška malá miniatura tablety u dávky, pokud existuje.
- Ukládání: fotografie se zmenší (delší strana cca 2000 px, JPEG) a ukládají se v datech aplikace, ne do knihovny fotek uživatele. Synchronizují se přes CloudKit jako přílohy. Mazání léku smaže i fotografie.
- Rozpoznávání textu z letáku je mimo rozsah v1.

### 3.8 Apple Health

- Volitelný zápis potvrzené dávky do HealthKit.
- Čtení se nepožaduje, pokud to není nutné.
- Uživatel si oprávnění může kdykoli odebrat v Nastavení.

### 3.9 Widgety

- **iPhone a iPad:** widget „Dnes“ (seznam dávek, tlačítko potvrdit), widget na zamykací obrazovce s nejbližší dávkou.
- **Mac:** widget „Dnes“ v Centru oznámení.
- Stav widgetu se synchronizuje přes sdílená data (App Group).

### 3.10 Synchronizace

- Automaticky přes iCloud (CloudKit) při přihlášení uživatele k Apple ID.
- Bez přihlášení funguje aplikace lokálně.
- Konflikty: poslední změna vyhrává na úrovni jednotlivého záznamu. Potvrzení dávky má přednost před „vynecháno“.
- Stav synchronizace viditelný v nastavení (naposledy synchronizováno, chyby).

### 3.11 Nastavení

- Jazyk: čeština a angličtina. Aplikace se řídí jazykem systému, resp. jazykem nastaveným pro aplikaci v Nastavení systému. V aplikaci je odkaz, jak jazyk změnit.
- Vzhled: světlý, tmavý, podle systému.
- Výchozí odklad notifikace, počet opakování, lhůta pro „zmeškáno“.
- Upozornění na zásoby: zapnout/vypnout, kolik dní předem.
- Správa oprávnění (notifikace, fotoaparát, Health).

## 4. Datový model (návrh)

```
Medication
  id: UUID
  name: String
  dosageText: String?          // "500 mg"
  unitsPerDose: Int            // kusů na dávku, výchozí 1
  notes: String?
  colorHex: String?
  createdAt: Date
  isArchived: Bool
  archivedAt: Date?            // po tomto datu se z plánu nedopočítávají dávky

  // zásoba
  tracksStock: Bool
  stockCount: Int              // aktuální počet kusů doma
  lowStockThreshold: Int       // hranice upozornění
  stockCountedAt: Date?        // kdy uživatel naposledy zadal/spočítal zásobu
  stockAtLastCount: Int        // kolik kusů tehdy zadal (základ pro kontrolu)
  lowStockNotifiedAt: Date?    // aby notifikace o docházející zásobě přišla jen jednou

Schedule
  id: UUID
  medication: Medication
  weekdays: [Int]              // 1–7 (Calendar.weekday, 1 = neděle)
  minutesOfDay: [Int]          // časy jako minuty od půlnoci
  mealRelation: enum?          // before / with / after / any
  startDate: Date
  endDate: Date?
  isPaused: Bool

DoseEvent                      // vzniká až při akci uživatele
  id: UUID
  medication: Medication
  scheduledAt: Date            // u dávky mimo plán = čas užití
  status: enum                 // pending / taken / skipped / missed
  takenAt: Date?
  updatedAt: Date              // pro řešení konfliktů
  source: enum                 // app / notification / widget / health / reconciliation
  isUnscheduled: Bool          // dávka mimo plán

MedicationPhoto
  id: UUID
  medication: Medication
  kind: enum                   // package / pill / leaflet
  pageIndex: Int               // pořadí stránek letáku, jinak 0
  imageData: Data              // JPEG, zmenšený; externí úložiště (externalStorage)
  createdAt: Date
```

Odvozené hodnoty (nepersistují se): stav plánované dávky bez záznamu (čeká / zmeškáno podle lhůty), očekávaná zásoba = `stockAtLastCount − vzaté dávky od stockCountedAt × unitsPerDose`, datum dojití zásoby.

Pravidla pro CloudKit: všechny atributy mají výchozí hodnotu nebo jsou volitelné, žádné unikátní constrainty, vztahy volitelné. Fotografie jako `externalStorage`, aby CloudKit použil přílohy (asset) místo záznamu.

## 5. Nefunkční požadavky

- **Soukromí:** žádná analytika, žádné reklamy, žádné třetí strany. Data i fotografie zůstávají v iCloudu uživatele a v zařízení.
- **Spolehlivost:** notifikace musí dorazit v nastavený čas. Ověřit v testech i při vypnutém Focus a v úsporném režimu.
- **Přístupnost:** VoiceOver, Dynamic Type, kontrast, velké tlačítka pro potvrzení.
- **Výkon:** start aplikace do 1 s, widgety bez zatížení baterie (timeline po změnách, ne každou minutu). Fotografie zmenšené, miniatury cachované.
- **Lokalizace:** všechny texty přes String Catalog. Čeština i angličtina kompletní v každém vydání; nepřeložený text je chyba. Pozor na české množné číslo (1 dávka / 2 dávky / 5 dávek) – používat plurálová pravidla katalogu, ne skládání řetězců.
- **Limit notifikací:** iOS dovolí nejvýše 64 naplánovaných lokálních notifikací. Plánovat jen nejbližší dny a přeplánovat při každém spuštění a změně.

## 6. Open source a licence

- Veřejný repozitář na GitHubu.
- Licence: **MIT** (nejjednodušší pro přispěvatele) nebo **GPL-3.0** (zajistí, že forky zůstanou open source). K rozhodnutí.
- Žádné závislosti, které by měnily licenci.
- Ve README jasné upozornění: aplikace není zdravotnický prostředek a nenahrazuje lékaře.
- Přispívání: issues, pull requesty, pokyny v `CONTRIBUTING.md`.
- Sestavení: Xcode projekt (případně generovaný XcodeGen), žádné placené účty pro build z úložiště.
- Podpis a distribuce: App Store a TestFlight vyžadují vývojářský účet (99 USD ročně). Build ze zdrojáků je zdarma s bezplatným Apple ID, ale s omezeními (7denní platnost podpisu na zařízení).

## 7. Testování

- Unit testy: výpočet plánu, stavy dávek, odečítání zásoby, odhad dojití zásoby, kontrola zásob (všechny tři výsledky), řešení konfliktů.
- UI testy: přidání léku, potvrzení dávky z notifikace, oprava stavu v kalendáři, přidání fotografie.
- Manuální testy na fyzických zařízeních: iPhone, iPad, Mac, sync mezi dvěma zařízeními přihlášenými stejným Apple ID.
- Testovat časové zóny, změnu času a přechod přes půlnoc.
- Testovat oba jazyky (screenshoty cs/en), délku českých textů v tlačítkách.

## 8. Milníky

Pořadí odpovídá prioritám: nejdřív jistota, že dávka byla vzata, pak historie a zásoby, pak fotografie, pak vše ostatní.

1. **Prototyp (iPhone):** jeden lék, jeden plán, lokální notifikace s akcemi, přehled dneška s tlačítkem „Vzal jsem“, čeština a angličtina.
2. **Historie a kalendář:** měsíční kalendář, oprava záznamů, souhrn, export CSV.
3. **Zásoby a kontrola:** sledování kusů, upozornění při docházení, odhad dojití, kontrola zásob podle spočítaných kusů.
4. **Fotografie:** krabička, tableta, příbalový leták (skener na iOS), prohlížení.
5. **Multiplatform:** iPad a Mac, adaptivní layout.
6. **Sync:** SwiftData + CloudKit včetně fotografií, test na dvou zařízeních.
7. **Widgety:** Dnes a zamykací obrazovka, interaktivní potvrzení.
8. **HealthKit:** zápis dávek.
9. **Beta (TestFlight), potom veřejné vydání.**

## 9. Otevřené otázky

1. Název aplikace a bundle ID. **Pracovní název MedRemind je obsazený:** existuje aplikace MedRemind (medremindapp.com, Android, verze pro iOS ohlášena). Alternativy v `design-options.md`.
2. Licence: MIT, nebo GPL-3.0?
3. Minimální verze: iOS 17 / macOS 14, nebo novější (kvůli API pro léky v HealthKitu)?
4. Potřebujete sdílení mezi více lidmi (rodina) už ve v1? Předpoklad: ne.
5. ~~Lokalizace: čeština a angličtina od začátku?~~ Rozhodnuto: ano, od prototypu.
6. Vývojářský účet Apple pro distribuci, nebo zatím jen sestavení ze zdrojáků?
7. Opakování nepotvrzené notifikace: bez serveru a bez běhu na pozadí lze jen předem naplánovat následné notifikace (např. +10 a +20 minut) a při potvrzení je zrušit. Stačí to?
8. Fotografie a iCloud: leták o 10 stránkách může mít 5–10 MB. Synchronizovat fotografie vždy, nebo jen přes Wi‑Fi / volitelně?
9. Zmeškaná dávka: má aplikace po uplynutí lhůty poslat ještě jedno upozornění „Dávku jste nepotvrdili“, nebo jen označit v přehledu?
