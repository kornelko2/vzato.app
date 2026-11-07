# Specifikace: Vzato (vzato.app)

Jednoduchá, zdarma a open source aplikace na připomínání léků pro iPhone, iPad a Mac. Jeden kódový základ, jedna aplikace pro všechna zařízení, data se synchronizují mezi zařízeními uživatele.

Stav: návrh v1, k 6. 11. 2026. Druhá revize: přidáno potvrzování dávek, historie a kalendář, zásoby a jejich kontrola, fotografie léku a příbalového letáku, čeština a angličtina od začátku. Třetí revize: primární trh je Česko a Slovensko (přidána slovenština), rodinné sdílení popsáno jako možné budoucí rozšíření, výsledek kontroly názvů. Čtvrtá revize: název Vzato, profily (děti, zvířata) jako možné rozšíření, strategie „malé jádro, otevřené dveře“. Pátá revize: rozhodnuto Core Data, bez serveru, minimalistická v1 (milníky 1–3), jedna univerzální aplikace pro iPhone, iPad a Mac. Šestá revize: tlačítko „Vzato“, předání dat při setkání (kapitola 14), ikona odložena. Stav implementace: fáze 1–4 hotové (6. 11. 2026). Sedmá revize: pomocník pro týdenní dávkovač (kapitola 15). Osmá revize: dávky po půlkách a čtvrtkách tablety, maďarština, jednotky dávky (kapky, ml…). Devátá revize: slučování duplicit mezi zařízeními a záznam činností (model verze 3).

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
- **Bez vlastního serveru.** Rozhodnuto 6. 11. 2026. Veškerá data jsou jen v zařízeních uživatele a v jeho iCloudu; vývojář k nim nemá přístup. Všechny funkce, včetně budoucích rozšíření (kapitoly 10–12), se staví jen nad infrastrukturou Apple a veřejnými API. Odůvodnění v kapitole 13.
- Primární trh: Česko a Slovensko. Čeština, slovenština, angličtina a maďarština od první verze (maďarština kvůli rodinným testerům).

### Mimo rozsah (v1)

- Doporučování dávek nebo lékové interakce. Aplikace nenahrazuje lékaře ani lékárníka.
- Účty a vlastní server.
- Sdílení mezi více uživateli (rodina, pečovatelé). Popsáno jako možné budoucí rozšíření v kapitole 10, ve v1 se nedělá.
- Android, web, Apple Watch (lze přidat později).
- Rozpoznávání textu (OCR) z krabiček a letáků. Fotografie se jen ukládají a zobrazují.

## 2. Platformy a technologie

| Oblast | Volba | Poznámka |
|---|---|---|
| Platformy | iOS 17+, iPadOS 17+, macOS 14+ | Jedna univerzální aplikace. Minimum kvůli interaktivním widgetům (iOS 17) a moderním SwiftUI API. Upřesnit po prototypu. |
| UI | SwiftUI, jeden multiplatform target | Mac a iPad používají stejné views s adaptivním layoutem. Žádný Catalyst. |
| Data | Core Data (`NSPersistentCloudKitContainer`) | Rozhodnuto 6. 11. 2026 místo SwiftData: jediné z obou, které umí CloudKit sdílení (kapitola 10). Lokální úložiště SQLite. |
| Sync | Core Data + CloudKit (privátní databáze) | Data patří uživateli v jeho iCloudu. Vývojář nemá server ani přístup k datům. Zdarma v rámci limitů iCloudu. |
| Notifikace | UserNotifications | Lokální notifikace, bez push serveru. |
| Fotografie | PhotosUI (výběr), AVFoundation / UIImagePickerController (fotoaparát), VisionKit (skenování letáku, jen iOS) | Fotografie se ukládají zmenšené, mimo knihovnu fotek uživatele. |
| Widgety | WidgetKit + App Intents | Stejný kód pro všechny platformy, interaktivní tlačítko „vzal jsem“ na iOS 17+ a macOS 14+. |
| Zdraví | HealthKit | Zápis užitých dávek. Ověřit aktuální API pro léky v dokumentaci Apple před implementací. |
| Jazyk | Swift | Minimální závislosti (ideálně žádné). |
| Lokalizace | String Catalog (`.xcstrings`) | Angličtina jako zdrojový jazyk, čeština, slovenština a maďarština jako překlady. |

## 3. Funkce

### 3.1 Léky a plán

- Přidání léku: název, síla (volný text, např. „500 mg“), **jednotka** (tablety, kapsle, kapky, ml, lžičky, vdechy, sáčky, injekce, kusy) a **množství na dávku** (výchozí 1 tableta; u tablet a kapslí lze půlka nebo čtvrtka, krok ¼; kapky a ml po celých), barva/ikona, poznámka. Množství se zobrazuje slovy s správným skloňováním ve všech jazycích („2 tablety“, „20 kapek“, „½ tablety“) na kartě Dnes, v časové ose i v notifikaci, aby uživatel vždy viděl, kolik si má vzít.
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
- **„Už můžete jíst“:** u léku užívaného před jídlem (např. Letrox) se nastaví čekací doba (výchozí 30 min, krok 15 min). Po potvrzení dávky přijde v daný čas notifikace „Už můžete jíst“ a na obrazovce Dnes běží odpočet „Jíst od 7:05“. Připomínky léků a „Už můžete jíst“ mají každá jiný zvuk (zvonek Vzato / jemná melodie Vzato / zvuk systému, volba v Nastavení › Zvuky s přehráním). Vrácení dávky upomínku zruší; u dávky zaznamenané dodatečně, kdy už čekací doba uplynula, se nic neplánuje.

### 3.3 Potvrzení a záznam dávek

Potvrzení „vzal jsem“ je hlavní akce aplikace. Musí být vždy na jedno klepnutí a vždy vidět, co už bylo vzato.

Design: zvolen směr C „Jistota“ (viz `design-options.md`). Obrazovka Dnes má nahoře jednu velkou kartu s nejbližší nebo nejstarší nepotvrzenou dávkou, miniaturou tablety a obřím tlačítkem „Vzal jsem“, pod ní „Odložit“ a „Přeskočit“, a dále celý den jako časovou osu. Ostatní obrazovky jsou systémové seznamy.

- Přehled dneška: seznam dávek rozdělený na „Teď“ (čeká nebo po termínu), „Později“ a „Hotovo“. Stav: čeká / vzato / vynecháno / zmeškáno.
- Velké tlačítko „Vzato“ (rodově neutrální, shodné s názvem aplikace; rozhodnuto 6. 11. 2026) u každé čekající dávky. Potvrzení lze udělat z aplikace, z notifikace i z widgetu.
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

- U léku lze zapnout sledování zásoby: počet kusů doma a počet kusů na dávku. Oboje může být desetinné (10,5 tablety), zobrazuje se jako 10½; odečítá se přesně podle kusů na dávku (½, ¼).
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
- **Mac:** widget „Dnes“ v Centru oznámení a na ploše.
- Tlačítko „Vzato“ ve widgetu potvrdí dávku bez otevření aplikace; widget sám nesynchronizuje, zápis přenese aplikace.
- Stav widgetu se synchronizuje přes sdílená data (App Group).

### 3.10 Synchronizace

- Automaticky přes iCloud (CloudKit) při přihlášení uživatele k Apple ID.
- Bez přihlášení funguje aplikace lokálně.
- Konflikty: dvě zařízení mohou stejnou dávku zaznamenat dřív, než se synchronizují. Po synchronizaci se záznamy sloučí podle pevného pravidla, stejného na všech zařízeních: **vzato má vždy přednost** před přeskočeno, pak nejdřívější čas užití, pak nejdřívější zápis, pak identifikátor záznamu. Ještě před sloučením obrazovka i widget ukazují jen vítězný záznam. Zásoba se při sloučení nemění. Každé sloučení se zapíše do záznamu činností. U ostatních polí platí poslední změna.
- **Záznam činností:** každá akce s dávkou (vzato, přeskočeno, vráceno, dávka navíc), spočítání zásoby, kontrola zásoby a každé automatické sloučení se trvale zapíše: kdy, co, který lék, která dávka, na kterém zařízení a odkud (aplikace, notifikace, widget, kontrola zásoby). Záznamy se nemění, synchronizují se a přežijí smazání léku. Zobrazení a export CSV v Nastavení › Záznam činností.
- Stav synchronizace viditelný v nastavení (naposledy synchronizováno, chyby).

### 3.11 Nastavení

- Jazyk: čeština, slovenština, angličtina a maďarština. Aplikace se řídí jazykem systému, resp. jazykem nastaveným pro aplikaci v Nastavení systému. V aplikaci je odkaz, jak jazyk změnit.
- Vzhled: světlý, tmavý, podle systému. Ikona aplikace: tableta (výchozí) nebo dávkovač. Na iOS a iPadOS se mění ikona na ploše, na Macu ikona v Docku za běhu aplikace (ve Finderu zůstává tableta, aplikace nesmí přepisovat vlastní podepsaný balíček).
- Výchozí odklad notifikace, počet opakování, lhůta pro „zmeškáno“.
- Upozornění na zásoby: zapnout/vypnout, kolik dní předem.
- Správa oprávnění (notifikace, fotoaparát, Health).

## 4. Datový model (návrh)

```
Profile                        // „Já“ je výchozí; další profily až v rozšíření (kapitola 12)
  id: UUID
  name: String
  kind: enum                   // person / pet
  colorHex: String?
  isDefault: Bool
  createdAt: Date

Medication
  id: UUID
  profile: Profile             // od fáze 1, i když UI zatím ukazuje jen „Já“
  name: String
  dosageText: String?          // "500 mg"
  unitKind: enum               // tablet / capsule / drop / milliliter / teaspoon / puff / sachet / injection / piece
  unitsPerDose: Double         // množství na dávku v dané jednotce, výchozí 1, krok ¼ u tablet
  notes: String?
  colorHex: String?
  createdAt: Date
  isArchived: Bool
  archivedAt: Date?            // po tomto datu se z plánu nedopočítávají dávky

  // zásoba
  tracksStock: Bool
  stockCount: Double           // aktuální počet kusů doma (může být 10,5)
  lowStockThreshold: Double    // hranice upozornění
  stockCountedAt: Date?        // kdy uživatel naposledy zadal/spočítal zásobu
  stockAtLastCount: Double     // kolik kusů tehdy zadal (základ pro kontrolu)
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

- **Soukromí:** žádná analytika, žádné reklamy, žádné třetí strany, žádný server vývojáře. Data i fotografie zůstávají v iCloudu uživatele a v zařízení. Podrobnosti a GDPR níže (5.1).
- **Spolehlivost:** notifikace musí dorazit v nastavený čas. Ověřit v testech i při vypnutém Focus a v úsporném režimu.
- **Přístupnost:** VoiceOver, Dynamic Type, kontrast, velké tlačítka pro potvrzení.
- **Výkon:** start aplikace do 1 s, widgety bez zatížení baterie (timeline po změnách, ne každou minutu). Fotografie zmenšené, miniatury cachované.
- **Lokalizace:** všechny texty přes String Catalog. Čeština, slovenština, angličtina i maďarština kompletní v každém vydání; nepřeložený text je chyba. Pozor na české a slovenské množné číslo (1 dávka / 2 dávky / 5 dávek) – používat plurálová pravidla katalogu, ne skládání řetězců.
- **Limit notifikací:** iOS dovolí nejvýše 64 naplánovaných lokálních notifikací. Plánovat jen nejbližší dny a přeplánovat při každém spuštění a změně.

### 5.1 Soukromí a GDPR bez serveru

Upozornění: toto není právní rada, jen shrnutí pro rozhodování; před vydáním si nechat zásady ochrany soukromí přečíst někým, kdo se tím živí.

- **Kdo s daty nakládá.** Aplikace ukládá údaje jen do zařízení a do privátní databáze iCloudu uživatele (CloudKit private database). K té vývojář nemá přístup ani technicky, ani smluvně. Synchronizaci poskytuje Apple uživateli na základě jeho smlouvy o iCloudu; vývojář tedy údaje uživatele nezpracovává a nevystupuje jako správce ani zpracovatel těchto zdravotních údajů. Právě to „bez serveru“ znamená: odpadá právní základ pro zpracování, DPIA, smlouvy se zpracovateli, hlášení incidentů a odpovědnost za cizí zdravotní data.
- **Co přesto platí.** App Store vyžaduje u každé aplikace **zásady ochrany soukromí** (odkaz i v aplikaci) a pravdivě vyplněné **Privacy Nutrition Labels**; u nás „Data Not Collected“. Zásady budou krátké a pravdivé: co aplikace ukládá, že to zůstává v zařízení a v iCloudu uživatele, že vývojář nic nesbírá, že uživatel vše smaže odinstalací a smazáním dat v iCloudu. Tím je splněna i informační povinnost vůči uživateli, kdyby se na vývojáře GDPR v něčem přece jen vztahovalo.
- **HealthKit.** Pravidla App Store zakazují ukládat údaje získané z HealthKit do iCloudu. Aplikace proto do HealthKit **jen zapisuje** a nikdy z něj nečte do vlastního synchronizovaného úložiště. Platí už od návrhu modelu.
- **Rodinné sdílení (kapitola 10).** Sdílí uživatel sám, vlastní údaje, konkrétní osobě, přes CloudKit. Vývojář opět nic nevidí. V zásadách soukromí popsat, co se sdílí a jak přístup odebrat.
- **Síťové požadavky mimo Apple.** Jediné jsou stahování příbalového letáku ze SÚKL/ŠÚKL (kapitola 11), a to jen na výslovnou akci uživatele; odesílá se pouze kód léku. IP adresa je technicky osobní údaj, proto to v zásadách zmínit jednou větou. Web vzato.app bude statický, bez cookies a bez měření.
- **Nezdravotnická aplikace.** Nic nedoporučuje, nediagnostikuje, nehodnotí. Upozornění „nenahrazuje lékaře ani lékárníka“ v aplikaci, v App Store i v README.

## 6. Open source a licence

- Veřejný repozitář na GitHubu.
- Licence: **MPL-2.0** (Mozilla Public License), rozhodnuto 6. 11. 2026. Změny v souborech projektu musí zůstat otevřené, přitom je licence slučitelná s podmínkami App Storu (na rozdíl od GPL) a nevyžaduje od přispěvatelů CLA. Název Vzato a ikona nejsou součástí licence; smí je používat jen oficiální sestavení.
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
- Testovat všechny čtyři jazyky (screenshoty cs/sk/en/hu), délku českých, slovenských a maďarských textů v tlačítkách. Maďarský překlad nechat zkontrolovat rodilým mluvčím.

## 8. Milníky

Pořadí odpovídá prioritám: nejdřív jistota, že dávka byla vzata, pak historie a zásoby, pak fotografie, pak vše ostatní. **Milníky 1–3 tvoří v1.** Multiplatformní layout se dělá průběžně, protože je to jeden target; milník 5 je jen jeho dotažení.

1. **Prototyp (iPhone):** jeden lék, jeden plán, lokální notifikace s akcemi, přehled dneška s tlačítkem „Vzal jsem“, čeština, slovenština a angličtina.
2. **Historie a kalendář:** měsíční kalendář, oprava záznamů, souhrn, export CSV.
3. **Zásoby a kontrola:** sledování kusů, upozornění při docházení, odhad dojití, kontrola zásob podle spočítaných kusů.
4. **Fotografie:** krabička, tableta, příbalový leták (skener na iOS), prohlížení.
5. **Multiplatform:** iPad a Mac, adaptivní layout.
6. **Sync:** Core Data + CloudKit včetně fotografií, test na dvou zařízeních.
7. **Widgety:** Dnes a zamykací obrazovka, interaktivní potvrzení.
8. **HealthKit:** zápis dávek.
9. **Beta (TestFlight), potom veřejné vydání.**

## 9. Otevřené otázky

1. ~~Název aplikace a bundle ID.~~ Rozhodnuto 6. 11. 2026: **Vzato**, projekt a doména **vzato.app**, bundle ID `app.vzato`. Zbývá ověřit ochranné známky (ÚPV ČR, ÚPV SR, EUIPO) a zaregistrovat domény vzato.app, vzato.cz, vzato.sk (whois: volné).
2. ~~Licence: MIT, nebo GPL-3.0?~~ Rozhodnuto: MPL-2.0 (viz kapitola 6).
3. Minimální verze: iOS 17 / macOS 14, nebo novější (kvůli API pro léky v HealthKitu)?
4. ~~Potřebujete sdílení mezi více lidmi (rodina) už ve v1?~~ Rozhodnuto: ne. Zůstává jako možné rozšíření, kapitola 10. Kvůli němu zvoleno Core Data od začátku (viz 10.3).
5. ~~Lokalizace: čeština a angličtina od začátku?~~ Rozhodnuto: čeština, slovenština a angličtina od prototypu.
6. Vývojářský účet Apple pro distribuci, nebo zatím jen sestavení ze zdrojáků?
7. Opakování nepotvrzené notifikace: bez serveru a bez běhu na pozadí lze jen předem naplánovat následné notifikace (např. +10 a +20 minut) a při potvrzení je zrušit. Stačí to?
8. Fotografie a iCloud: leták o 10 stránkách může mít 5–10 MB. Synchronizovat fotografie vždy, nebo jen přes Wi‑Fi / volitelně?
9. Zmeškaná dávka: má aplikace po uplynutí lhůty poslat ještě jedno upozornění „Dávku jste nepotvrdili“, nebo jen označit v přehledu?

## 10. Možné rozšíření (mimo v1): rodinné sdílení

V Česku a na Slovensku je běžné, že dospělé děti hlídají léky starším rodičům. Tato kapitola popisuje, co by takové sdílení znamenalo, aby šlo později rozhodnout s plným vědomím ceny. **Ve v1 se neimplementuje.**

### 10.1 Co by uživatel dostal

- Rodič (vlastník dat) pozve pečovatele odkazem (Zprávy, e-mail). Pečovatel vidí v aplikaci druhý profil „Maminka“ vedle svých léků.
- Pečovatel vidí dnešní dávky a jejich stav, historii a stav zásob. Dostane upozornění, když dávka není potvrzena ani po uplynutí lhůty („Maminka nepotvrdila Letrox 6:30“).
- Pečovatel může po telefonátu dávku potvrdit za rodiče; záznam má zdroj „pečovatel“ a je to v historii vidět.
- Rodič kdykoli vidí, kdo má přístup, a může ho jedním klepnutím odebrat.

### 10.2 Jak by to šlo bez vlastního serveru

- **CloudKit sdílení (CKShare):** data zůstávají v iCloudu rodiče, Apple je zpřístupní pozvanému účtu. Žádný server vývojáře, žádné účty v aplikaci, žádná data mimo Apple.
- **Upozornění pečovateli:** CloudKit odběr (subscription) na změny ve sdílené zóně doručí push notifikaci na zařízení pečovatele. Stav „zmeškáno“ ale u nás nevzniká zápisem, dopočítává se z plánu; pro upozornění by zařízení rodiče muselo zmeškání zapsat (při dalším otevření aplikace nebo z notifikační akce), případně by si pečovatelova aplikace lhůtu počítala sama z plánu. To je řešitelné, ale je to další logika.
- **Podmínky:** oba potřebují zařízení Apple přihlášené k iCloudu. Rodič tedy musí mít iPhone nebo iPad.

### 10.3 Co by to stálo

- **Úložiště:** SwiftData (iOS 17/18) CloudKit sdílení nepodporuje. Sdílení umí Core Data přes `NSPersistentCloudKitContainer` (od iOS 15). Pokud má být sdílení někdy reálné, je levnější začít na Core Data hned, než později přepisovat modely a dotazy; SwiftUI s Core Data funguje dobře (`@FetchRequest`). Pokud se sdílení neplánuje, SwiftData je jednodušší. **Toto je jediné rozhodnutí, které sdílení vyžaduje už teď. Rozhodnuto 6. 11. 2026: Core Data.**
- **UI navíc:** přepínání profilů, pozvánka a správa přístupu, oddělené notifikace pro vlastní a cizí dávky, označení zdroje „pečovatel“.
- **Soukromí:** sdílení zapíná jen vlastník dat, výslovně a pro konkrétní osobu; v aplikaci je vidět, co a s kým se sdílí; odebrání přístupu funguje okamžitě. Zdravotní data neopouštějí iCloud zúčastněných. Žádná analytika ani server to nemění.
- **Pracnost:** zhruba velikost fáze Sync znovu (samostatná fáze po v1), plus testování na třech zařízeních se dvěma Apple ID.

## 11. Možné rozšíření (mimo v1): databáze léčiv SÚKL a ŠÚKL

Oba státní ústavy poskytují data o registrovaných lécích zdarma a bez API klíče. Ověřeno 6. 11. 2026. Použití je volitelné; aplikace musí plně fungovat i bez něj (ruční zadání).

### 11.1 Co by to přineslo

- **Našeptávání při přidání léku:** uživatel napíše „Ibal…“ a vybere „IBALGIN 400, 400MG TBL FLM 24“. Vyplní se název, síla, léková forma, velikost balení (základ pro zásobu), ATC skupina.
- **Oficiální příbalový leták:** k českému léku lze stáhnout aktuální PIL (a SPC) jako PDF přímo ze SÚKL podle kódu SÚKL. Doplňuje fotografii letáku z kapitoly 3.7; fotka zůstává pro léky, které v databázi nejsou (zahraniční, doplňky stravy).
- **Sken krabičky:** kód SÚKL je na každé české krabičce; čárový kód (EAN) by umožnil přidat lék jedním skenem, pokud je EAN v datech (ověřit v otevřených datech DLP).

### 11.2 Zdroje

| | Česko – SÚKL | Slovensko – ŠÚKL |
|---|---|---|
| API | `https://prehledy.sukl.cz/dlp/v1/` (OpenAPI 2.0.0, JSON, bez klíče) | `https://api.sukl.sk/json/lieky_ui42.php?limit=…&offset=…` (JSON, stránkované, bez klíče) |
| Rozsah | cca 70 000 kódů SÚKL; detail: název, síla, léková forma, balení, cesta podání, ATC, držitel, způsob výdeje, expirace; `/slozeni/{kod}` léčivé látky; `/ciselniky/{nazev}` (lékové formy, ATC, cesty podání…) | Seznam registrovaných liekov: kód ŠÚKL, názov, doplnok (forma/balenie), ATC, držiteľ, výdaj, stav registrácie, lieková forma |
| Dokumenty | `/dokumenty-metadata/{kod}` → PIL, SPC, OBAL; `/dokumenty/{kod}/pil` vrací PDF | Dokumenty PIL/SPC jsou na webu ŠÚKL u detailu lieku; API pro ně neověřeno |
| Hledání podle názvu | **Není.** API vrací jen seznam kódů (`/lecive-pripravky?typSeznamu=dlpo&uvedeneCeny=false`) a detail po jednom. Pro našeptávání je nutné mít lokální index. | Jen stránkování, bez filtru; stáhnout celý seznam a indexovat lokálně |
| Otevřená data | `opendata.sukl.cz` – DLP jako ZIP s CSV, aktualizace měsíčně, popis rozhraní k dispozici | Národný katalóg otvorených dát (data.slovensko.sk), licence CC0 1.0 |
| Zvláštnosti | Pouze „dávky“ (měsíční snímky), parametr `obdobi` | Odpověď je JSON obalený v HTML stránce, před parsováním oříznout |

### 11.3 Jak by se to použilo bez serveru a bez ztráty soukromí

- Aplikace nese **vlastní kompaktní index** (kód, název, síla, forma, balení, ATC, EAN) vygenerovaný skriptem z otevřených dat při sestavení; aktualizuje se s vydáním aplikace. Našeptávání tak funguje offline a nikam se neposílá, co uživatel píše.
- Na SÚKL/ŠÚKL se přistupuje jen při výslovné akci uživatele („Stáhnout příbalový leták“). Požadavek obsahuje jen kód léku, žádné osobní údaje; stažené PDF se uloží lokálně (a synchronizuje jako fotografie).
- Licence otevřených dat SÚKL ověřit před použitím (zpravidla volné užití s uvedením zdroje); slovenská data jsou CC0. Zdroj uvést v aplikaci v sekci O aplikaci.
- Žádné zdravotní informace z SPC (dávkování, interakce) se nezobrazují jako doporučení; odkazuje se na oficiální dokument. Platí kapitola 1, Mimo rozsah.

### 11.4 Co by to stálo

- Build skript (CSV → SQLite/JSON index, kontrola velikosti; odhad 2–5 MB pro CZ+SK), našeptávač ve formuláři, stažení a zobrazení PDF, správa aktualizací indexu. Samostatná fáze po v1, menší než fáze Sync.

## 12. Možné rozšíření (mimo v1): více profilů (děti, domácí zvířata)

Rodiče hlídají léky dětem, majitelé zvířatům (odčervení, antibiotika, kapky). Dnes si to lidé řeší v jedné aplikaci jako „své“ léky s matoucími názvy.

### 12.1 Co by uživatel dostal

- Profily „Já“, „Anička“, „Mikeš“ s barvou nebo ikonou (osoba / zvíře). Lék patří profilu.
- Přehled Dnes zobrazuje dávky všech profilů, u každé jméno a ikona; filtr na jeden profil. Velká karta směru C říká „Mikeš · Milbemax“.
- Notifikace nesou jméno („Anička: Nurofen 8:00“). Historie, kalendář, zásoby a export jsou per profil.
- Vše zůstává v jednom iCloudu uživatele, žádné sdílení. (Sdílení profilu s jiným člověkem je kapitola 10 a jde kombinovat: sdílí se profil, ne celá aplikace.)

### 12.2 Co by to stálo

- **Datový model:** entita `Profile` a vazba z léku. **Zavést od fáze 1** s jediným výchozím profilem „Já“, UI pro další profily skrýt. Pozdější doplnění vazby do existujících dat znamená migraci a je zbytečně drahé; teď stojí pár řádků.
- **UI:** správa profilů v Nastavení, výběr profilu ve formuláři léku, jméno v řádku dávky a v notifikaci, filtr v Dnes a Historii. Odhad: menší než fáze Historie.
- **Zvířata:** veterinární léky nejsou v databázi SÚKL (lidské léky); vede je ÚSKVBL. Pro zvířata zůstává ruční zadání a fotografie.
- **Soukromí:** nic nového, data jsou stále jen uživatelova.

## 13. Strategie: malé jádro, otevřené dveře

Otázka zní, zda aplikaci pojmout jednoduše, nebo rovnou „velkou“ se serverem, sdílením a certifikací. Odpověď: **malé jádro bez serveru, ale čtyři levná rozhodnutí hned na začátku, aby dveře zůstaly otevřené.**

Co znamená „velká“ cesta a proč ji nejít:
- **Server** je jediná věc, která skutečně mění hru. Jakmile zdravotní údaje (zvláštní kategorie podle čl. 9 GDPR) opustí zařízení uživatele na server provozovatele, přibývá: právní základ a souhlasy, posouzení vlivu (DPIA), zabezpečení a jeho dokumentace, hosting a provoz, zálohy, incidenty, náklady měsíčně, odpovědnost jedné osoby za cizí zdravotní data. Pro open source projekt jednoho vývojáře je to neúměrné.
- **Certifikace jako zdravotnický prostředek** (MDR) není potřeba, dokud aplikace jen připomíná a zapisuje, co uživatel sám zadal, a nic nedoporučuje (dávkování, interakce, diagnózy). Proto to specifikace drží mimo rozsah a proto se u databáze léčiv (kapitola 11) jen odkazuje na oficiální dokument. Hranici hlídat při každé nové funkci.
- **App Store** chce u zdravotních aplikací zásady ochrany soukromí, jasné upozornění, že nejde o lékařskou radu, a správně vyplněné „Privacy Nutrition Labels“. To je administrativa, ne překážka.

Vše, co bylo zatím zmíněno, jde **bez serveru** přes infrastrukturu Apple: sync (CloudKit), rodinné sdílení (CKShare + odběry), profily (lokální model), databáze léčiv (veřejná API, offline index), fotografie (CloudKit přílohy), widgety, Health.

Čtyři rozhodnutí teď, aby to tak zůstalo:
1. **`Profile` v datovém modelu od fáze 1** (kapitola 12), UI jen „Já“.
2. **Úložiště podle sdílení:** pokud je rodinné sdílení reálný cíl do roka, Core Data s `NSPersistentCloudKitContainer` od začátku; jinak SwiftData. Pozdější přechod je přepis modelové vrstvy. Rozhodnuto 6. 11. 2026: **Core Data**.
3. **Služby nezávislé na úložišti:** plánování dávek, zásoby, kontrola zásob pracují s jednoduchými strukturami a protokoly, ne přímo s modely úložiště. Pak je jedno, co je pod nimi.
4. **Žádný server, dokud není důvod, který Apple neumí** (např. Android). Pak to bude vědomé rozhodnutí s rozpočtem, ne postupné přirůstání.

### Proč ne ani „zero-knowledge“ server

Zvažovaná varianta: vlastní server, který vidí jen šifrované bloby (end-to-end šifrování) a slouží jen k synchronizaci, třeba jednou denně. Srovnání s CloudKitem:

| | CloudKit (iCloud uživatele) | Vlastní zero-knowledge server |
|---|---|---|
| Přístup vývojáře k datům | žádný (privátní databáze); s Advanced Data Protection nemá klíče ani Apple | žádný k obsahu, ale vidí účty, IP adresy, časy a objemy |
| Rychlost syncu | minuty, zdarma, push změn | jak si naprogramujeme a zaplatíme; „jednou denně“ je pro otázku „vzala maminka ráno lék?“ k ničemu |
| Sdílení s rodinou | CKShare: identita, pozvánka, oprávnění, odebrání přístupu hotové od Apple | nutno postavit výměnu klíčů mezi uživateli, pozvánky, odvolání přístupu; to je kryptografický projekt sám o sobě |
| Ztráta zařízení / zapomenuté heslo | řeší Apple ID | řeší vývojář: obnovovací klíče, jinak data nenávratně pryč |
| Provoz a náklady | žádné | hosting, zálohy, aktualizace, monitoring, měsíční platba u aplikace zdarma |
| GDPR | vývojář nezpracovává nic | pořád zpracovává účty a metadata: zásady, zpracovatelská smlouva s hostingem, hlášení incidentů; méně než u otevřených dat, ne nula |
| Co navíc pro uživatele s iPhonem | — | nic |

Server by dával smysl jen tehdy, když CloudKit nestačí: **klient pro Android nebo web** (rodič se starým Androidem, pečovatel bez iPhonu) nebo uživatel bez iCloudu. Pro sdílení s rodinou uvnitř světa Apple server potřeba není, to řeší CKShare. Až bude Android na stole, bude to samostatné rozhodnutí s rozpočtem, a i pak je lepší začít u otázky, zda stačí export/odkaz než plnohodnotný server.

Zkratka: jádro ve fázích 1–3 je malá aplikace a má zůstat malá. Rozšíření v kapitolách 10–12 nejsou „velká aplikace“, jsou to další fáze stejné malé aplikace. Horké to není, pokud se nepostaví server. **Rozhodnuto 6. 11. 2026: server se nestaví.**

## 14. Možné rozšíření (mimo v1): předání dat při setkání (QR kód, export, souhrn)

Alternativa k živému sdílení z kapitoly 10: data se nepředávají průběžně, ale **jednorázově a vědomě**, když se lidé potkají nebo když uživatel klepne na „poslat“. Lékař v ordinaci, synovec na návštěvě. Žádný přístup na dálku, žádné pozvánky, žádný stav „kdo co vidí“. Soukromí je triviální: uživatel ukáže nebo pošle přesně to, co chce, a tím to končí.

### 14.1 Varianty

| Varianta | Jak | Hodí se na | Omezení |
|---|---|---|---|
| **Ukázat obrazovku** | Souhrn za období (léky, dodržení, zmeškané dávky, zásoby) jako jedna přehledná obrazovka, velké písmo | lékař, 2 minuty v ordinaci | nic se nepřenáší, jen se ukáže |
| **QR kód na displeji** | Aplikace zobrazí QR, druhý telefon ho naskenuje (Vzato nebo fotoaparát). Obsah: kompaktní JSON, komprimovaný; jeden QR unese cca 2–3 KB, tj. zhruba měsíc dávek pro několik léků; delší období jako série QR kódů (animovaná sekvence) | synovec s Vzato, předání seznamu léků novému zařízení | kapacita; přijímající strana potřebuje Vzato pro import, fotoaparát přečte jen text |
| **AirDrop / sdílení souboru** | Export (CSV, PDF souhrn, nebo `.vzato` JSON balíček) přes systémové sdílení | kdokoli s iPhonem/Macem vedle vás | vyžaduje blízkost nebo jiný kanál |
| **Šifrovaný soubor e‑mailem** | `.vzato` balíček zašifrovaný heslem (AES‑GCM, heslo sdělené jinou cestou), příjemce otevře ve Vzato nebo zadá heslo v aplikaci | lékař před kontrolou, rodina na dálku | heslo se musí předat zvlášť; e‑mail odesílá uživatel ručně (iOS nedovolí aplikaci posílat e‑maily samo) |
| **Denní souhrn SMS / e‑mailem** | Jednou denně text „Dnes 3 ze 3 dávek, zásoba Letrox 12 dní“ | pečující osoba bez iPhonu, i na Androidu | iOS nedovolí aplikaci odeslat SMS ani e‑mail bez klepnutí uživatele; **automaticky** to bez serveru nejde. Jde to přes Zkratky (automatizace v daný čas otevře Vzato a nabídne odeslání) nebo jako „jedno klepnutí ráno“ |

### 14.2 Co by to znamenalo

- **Formát balíčku `.vzato`:** JSON s verzí schématu, profily, léky, plány, záznamy za zvolené období, volitelně fotografie; stejný formát pro QR (bez fotografií, komprimovaný) i pro soubor. Import s náhledem „co se přidá“, sloučení podle `id`, nic se nepřepisuje bez potvrzení.
- **Souhrn pro lékaře:** nová obrazovka a PDF export (fáze 2 má CSV, PDF je nad rámec). Obsah: seznam léků s dávkováním, dodržení za období, zmeškané dávky, dávky mimo plán, zásoby.
- **Bez serveru:** všechno probíhá na zařízení nebo přes systémové sdílení. Šifrování přes CryptoKit. Žádný nový vztah k GDPR, uživatel data předává sám.
- **Vazba na Android:** souhrn e‑mailem/SMS a čitelný QR (prostý text) jsou jediné cesty, jak dostat informace k někomu bez zařízení Apple, aniž by vznikl server. To je silný argument pro tuto kapitolu oproti kapitole 10.
- **Pracnost:** souhrn + PDF malá; `.vzato` balíček a import střední; QR sekvence střední; šifrování malé. Celkově menší než kapitola 10 a bez jejích rizik.

Doporučení: pokud se někdy bude řešit „jak dát data lékaři nebo rodině“, začít tady (souhrn, PDF, `.vzato` balíček přes sdílení), a kapitolu 10 nechat až na případ, kdy je nutné průběžné sledování na dálku.

## 15. Možné rozšíření (mimo v1): pomocník pro týdenní dávkovač

Hodně lidí si léky na týden dopředu rozdělí do plastového dávkovače (7 dní × ráno/poledne/večer/noc). Vzato může s plněním pomoci a potom potvrzovat celý díl najednou, protože „vzal jsem obsah ranní přihrádky“ je jedna akce, ne tři.

### 15.1 Co by uživatel dostal

- **Rozložení dávkovače:** uživatel vybere typ ze seznamu běžných: 7 × 1 (jen ráno), 7 × 2 (ráno/večer), 7 × 3 (ráno/poledne/večer), 7 × 4 (ráno/poledne/večer/noc), 1 × 4 (denní). Hranice dílů jsou časová okna (výchozí: ráno do 10:00, poledne 10–15, večer 15–20, noc po 20:00), která lze upravit. Každý čas v plánu léku tak spadne do jednoho dílu.
- **Průvodce plněním:** obrazovka „Naplnit dávkovač“ na příští týden: mřížka den × díl, v každé buňce léky s počtem kusů a miniaturou tablety (z kapitoly 3.7), aby se nepletly. Při plnění se buňky odškrtávají. Nahoře součet kusů na týden pro každý lék a porovnání se zásobou: „Ibuprofen: potřeba 14, doma 4“ s odkazem na kontrolu zásoby. Plnění dávkovače je zároveň přesný okamžik pro spočítání zásoby (kapitola 3.6).
- **Potvrzení celého dílu:** na obrazovce Dnes jsou dávky seskupené po dílech a u každého je tlačítko „Vzato: ráno“, které potvrdí všechny dávky dílu najednou. Jednotlivé dávky jdou stále potvrdit zvlášť. Velká karta směru C ukazuje místo jednoho léku celý díl („Ráno · 3 léky“), pokud je dávkovač zapnutý.
- **Notifikace po dílech:** místo tří notifikací v 8:00 jedna „Ráno: Letrox, Ibuprofen, Vitamin D“ s akcí „Vzato“ pro celý díl. Šetří limit 64 notifikací a je to pro uživatele dávkovače přirozenější.
- **Nic se neplánuje dvakrát:** dávkovač nemění plán léků, jen jeho zobrazení a způsob potvrzení. Léky mimo rozložení (např. „každé 2 dny“, kapky) zůstávají jako samostatné dávky.

### 15.2 Co by to znamenalo

- **Model:** entita `Organizer` na profil: typ rozložení, hranice časových oken, `isEnabled`. Nic v záznamech dávek se nemění; seskupení se dopočítává z časů. Žádná migrace stávajících dat.
- **Logika:** `OrganizerService.slot(for: Date) -> OrganizerSlot`, seskupení `DoseSlot` po dílech, souhrn kusů na týden, porovnání se zásobou. Testovatelné bez UI.
- **UI:** výběr rozložení v Nastavení, obrazovka Naplnit dávkovač, seskupení a hromadné tlačítko na Dnes, varianta velké karty, hromadná notifikace.
- **Pracnost:** střední, zhruba jako fáze 3. Závisí na fotografiích (3.7) jen pro miniatury, jinak na ničem.
