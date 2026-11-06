# Název a designové směry

Doplněk ke `specification.md`. Kapitola 1 řeší název (původní pracovní název byl MedRemind), kapitola 2 čtyři směry vizuálního a interakčního designu. Na konci je doporučení.

---

## 1. Název aplikace

Kritéria: krátký, srozumitelný česky i slovensky (primární trh), bez diakritiky v bundle ID, nepůsobí jako „zdravotnický prostředek“, a hlavně **volný v App Store**. Apple odmítne název, který už má jiná aplikace na stejném storefrontu, a reaguje i na názvy zaměnitelné s existujícími. Kontrola provedena 6. 11. 2026 přes vyhledávání App Storu (storefronty CZ, SK, US, GB, DE), Google Play a web.

| Název | Význam | Stav v App Store | Poznámka |
|---|---|---|---|
| **Vzato** | Česky „vzato“ = hlavní akce aplikace; Slovák rozumí (sk „vzaté“) | **Volný** (CZ, SK, US, GB, DE; nic na Google Play ani na webu) | Nejsilnější kandidát. Krátké, neotřelé, přesně o tom, co aplikace dělá. |
| **Vezmi** | Rozkaz „vezmi (si lék)“, slovo je stejné v češtině i slovenštině | Volný podle webu, přes API nedoověřeno | Aktivní, trochu naléhavé. Výborně funguje v notifikaci („Vezmi: Letrox“). |
| **Dávka** | Dávka léku, stejné slovo v obou jazycích | Žádná shoda na webu, přes API nedoověřeno | Obecné slovo, hůř se hledá, slabá ochranná známka. |
| **Včas** | „Včas“, stejné v obou jazycích | Žádná shoda na webu | Hezké heslo („léky včas“), ale jako název příliš obecné. Spíš podtitul. |
| Lékovka | Lahvička na léky | **Obsazeno** – česká aplikace Lékovka (aplikacelekovka.cz, App Store i Google Play) | Vyřazeno. |
| Dóza / Doza | Nádobka na léky, zní jako *dose* | **Obsazeno** – „Doza – Medication Reminder“ a další čtyři Doza | Vyřazeno. |
| Pillar | *Pill* + pilíř | **Obsazeno** – „Pillar: Medicine Reminder“ | Vyřazeno. |
| DoseDay | Dávka / den | **Obsazeno** – tři aplikace DoseDay | Vyřazeno. |
| TookIt | „Took it“ | **Obsazeno** – TookIt, plánování léků | Vyřazeno. |
| Tabletka | Malá tableta | Lékárenské aplikace Tabletka.by, Tabletki.ua; riziko zaměnitelnosti | Vyřazeno. |
| Užito | Správný lékárenský výraz | Apple ho používá jako popisek tlačítka v aplikaci Zdraví (Léky → „Užito“) | Vyřazeno kvůli zaměnitelnosti s Apple. |
| MedRemind (pracovní) | Popisný název | **Obsazeno** – MedRemind+, MedRemind – Pill Reminder, MedRemind (Android, iOS ohlášen) | Vyřazeno. |

**Rozhodnuto 6. 11. 2026: Vzato, projekt vzato.app.** V App Store jako „Vzato – léky včas“ (CZ), „Vzato – lieky včas“ (SK), „Vzato – Medication Reminder“ (EN); název samotný je stejný všude. Bundle ID `app.vzato` (podle domény vzato.app). Záloha: **Vezmi**.

Před konečným rozhodnutím ověřit ručně (vyhledávání webem tyto databáze nepokrývá):
- ochranné známky: ÚPV ČR (isdv.upv.gov.cz), ÚPV SR (indprop.gov.sk), EUIPO eSearch / TMview, třída 9 (software) a 44 (zdravotní služby);
- vyhledávání přímo v aplikaci App Store na iPhonu s CZ a SK účtem (API Apple vyhledává jen název a klíčová slova, ne podtitul);
- ~~domény `vzato.cz`, `vzato.sk`, `vzato.app`~~ – ověřeno whois/RDAP 6. 11. 2026: všechny tři volné (`vezmi.cz` a `davka.cz` jsou obsazené).

## 2. Designové směry

Všechny čtyři směry dodržují společný základ ze specifikace: potvrzení dávky na jedno klepnutí, VoiceOver, Dynamic Type, světlý i tmavý režim, jeden kód pro iPhone, iPad a Mac. Liší se v tom, co je na obrazovce první, jak vypadá a kolik vlastní grafiky vyžadují.

Barvy stavů jsou ve všech směrech stejné, aby je uživatel nemusel znovu učit:

| Stav | Barva | Symbol SF |
|---|---|---|
| Čeká | šedá | `clock` |
| Po termínu | oranžová | `exclamationmark.circle` |
| Vzato | zelená | `checkmark.circle.fill` |
| Přeskočeno | žlutošedá | `forward.circle` |
| Zmeškáno | červená | `xmark.circle` |
| Dochází zásoba | oranžový štítek | `exclamationmark.triangle` |

### Směr A – „Klinicky čistý“ (nativní, Apple Health)

Vzhled jako vestavěné aplikace Apple (Zdraví, Připomínky). Seznamy, sekce, systémové písmo San Francisco, bílá/černá plocha, jeden modrý akcent, zelené tlačítko Vzal jsem.

```
┌──────────────────────────────┐
│ Dnes                       + │
│                              │
│ ⚠ Ibuprofen: zbývá 4 kusy    │
│                              │
│ TEĎ                          │
│ ● Ibuprofen   400 mg  8:00   │
│   Po termínu        [Vzal ✓] │
│                              │
│ POZDĚJI                      │
│ ● Vitamin D   1 kapka 12:00  │
│ ● Ibuprofen   400 mg 20:00   │
│                              │
│ HOTOVO                       │
│ ● Letrox      50 µg   6:30   │
│   Vzato v 6:34            ✓  │
│                              │
├──────────────────────────────┤
│  Dnes   Historie  Léky  Nast.│
└──────────────────────────────┘
```

- **Navigace:** TabView (iPhone), NavigationSplitView (iPad, Mac).
- **Písmo:** SF Pro, systémové velikosti.
- **Barvy:** systémová modrá `#0A84FF`, zelená `#34C759`, pozadí systémové. Barva léku jen jako tečka.
- **Ikona:** bílá tableta na modrém pozadí.
- **Pro:** nejmenší práce, nejlepší přístupnost zdarma, na Macu vypadá správně bez úprav, snadné pro přispěvatele.
- **Proti:** bez osobnosti, splyne s ostatními; tlačítko Vzal jsem je malé (řádek seznamu).
- **Vhodné pro:** rychlý prototyp a starší uživatele, kteří znají systémové aplikace.
- **Pracnost:** nízká.

### Směr B – „Lékárnička“ (teplý, karty)

Přátelská aplikace do domácnosti. Krémové pozadí, zaoblené karty, SF Rounded, barvy léků jako velké barevné bloky, jemné ilustrace tablet.

```
┌──────────────────────────────┐
│ Dobré ráno            6. 11. │
│ 1 ze 4 dávek vzato           │
│                              │
│ ╭──────────────────────────╮ │
│ │ ▌Ibuprofen       8:00    │ │
│ │ ▌400 mg · po jídle       │ │
│ │ ▌ ⚠ zbývá 4              │ │
│ │ ▌        ( Vzal jsem ✓ ) │ │
│ ╰──────────────────────────╯ │
│ ╭──────────────────────────╮ │
│ │ ▌Vitamin D      12:00    │ │
│ │ ▌1 kapka   ( Vzal jsem ) │ │
│ ╰──────────────────────────╯ │
│ ╭──────────────────────────╮ │
│ │ ▌Letrox   6:30   ✓ 6:34  │ │
│ ╰──────────────────────────╯ │
├──────────────────────────────┤
│  ☀ Dnes   ▦ Kalendář  ⬡ Léky │
└──────────────────────────────┘
```

- **Navigace:** 3 záložky (Dnes, Kalendář, Léky), nastavení pod ozubeným kolem v Léky.
- **Písmo:** SF Rounded pro nadpisy, SF Pro pro text.
- **Barvy:** krémová `#FBF7F0` / tmavá `#1C1A17`, akcent terakota `#D9704A`, zelená `#3DA35D`, paleta léků 8 odstínů (korál, šalvěj, levandule, med, …).
- **Ikona:** otevřená dóza s barevnými tabletami.
- **Pro:** osobnost, dobře se pamatuje, barvy léků pomáhají orientaci, tlačítko v každé kartě je velké.
- **Proti:** vlastní komponenty = více práce a víc testování na Macu (karty na Macu snadno vypadají jako mobilní aplikace); krémové pozadí vyžaduje pečlivý kontrast.
- **Vhodné pro:** rodinné každodenní používání, App Store screenshoty.
- **Pracnost:** střední.

### Směr C – „Jistota“ (jedna velká dávka napřed)

Obrazovka Dnes je podřízená jediné otázce: *co mám vzít teď a vzal jsem to už?* Nahoře je vždy jedna velká karta s nejbližší nebo nejstarší nepotvrzenou dávkou a obřím tlačítkem; zbytek dne je časová osa pod ní. Vysoký kontrast, velké písmo jako výchozí.

```
┌──────────────────────────────┐
│ Dnes 6. 11.          2/4 ✓   │
│                              │
│ ╭──────────────────────────╮ │
│ │  8:00 · PO TERMÍNU       │ │
│ │                          │ │
│ │  Ibuprofen               │ │
│ │  400 mg, po jídle   [📷] │ │
│ │                          │ │
│ │ ┌──────────────────────┐ │ │
│ │ │      VZAL JSEM       │ │ │
│ │ └──────────────────────┘ │ │
│ │   Odložit      Přeskočit │ │
│ ╰──────────────────────────╯ │
│                              │
│  6:30 ✓ Letrox      vzato 6:34│
│ 12:00 ○ Vitamin D            │
│ 20:00 ○ Ibuprofen            │
│                              │
├──────────────────────────────┤
│  Dnes   Historie  Léky  Nast.│
└──────────────────────────────┘
```

- **Navigace:** jako A (systémové záložky), ale Dnes má vlastní rozvržení.
- **Písmo:** SF Pro, výchozí velikost o stupeň větší, tlačítko `title2` tučně.
- **Barvy:** černobílý základ, jediný akcent zelená `#2E8B57` pro Vzal jsem; oranžová pouze pro „po termínu“. Barva léku jen jako proužek na kartě. V tmavém režimu černé pozadí (OLED).
- **Ikona:** velké zelené zaškrtnutí na tabletě.
- **Pro:** nejpříměji řeší hlavní riziko ze specifikace (zapomenutí, dvojí dávka); přirozeně se přenáší do widgetu a na zamykací obrazovku (stejná karta); miniatura tablety přímo v kartě odpovídá na „je to ten správný lék?“.
- **Proti:** při mnoha lécích ve stejný čas je velká karta jen pro jeden z nich (řešit stránkováním karet); vizuálně strohé.
- **Vhodné pro:** uživatele s několika léky denně, seniory, každého, kdo si není jistý, zda už dávku vzal.
- **Pracnost:** nízká až střední (jedna vlastní karta, zbytek nativní).

### Směr D – „Plánovač“ (kalendář jako domov)

Domovská obrazovka je den na časové ose s týdenním pruhem nahoře. Dnes, historie i budoucnost jsou jedna obrazovka, jen se posouvá. Barvy léků jsou hlavní vizuální prvek, dávky jsou barevné bloky.

```
┌──────────────────────────────┐
│ ‹  Po Út St Čt [Pá] So Ne  › │
│     2  3  4  5  6   7  8     │
│    ●  ●  ●  ◐  ◐             │
│                              │
│  6 ─ ▇ Letrox         ✓      │
│  7 ─                         │
│  8 ─ ▇ Ibuprofen  [Vzal ✓]   │
│  9 ─                         │
│ 10 ─                         │
│ 11 ─                         │
│ 12 ─ ▇ Vitamin D             │
│ 13 ─                         │
│  …                           │
│ 20 ─ ▇ Ibuprofen             │
│                              │
├──────────────────────────────┤
│  Kalendář     Léky     Nast. │
└──────────────────────────────┘
```

- **Navigace:** 3 záložky; Kalendář nahrazuje Dnes i Historii. Měsíční pohled po klepnutí na datum.
- **Písmo:** SF Pro, menší hustší text.
- **Barvy:** neutrální pozadí, bloky v barvě léku, stavové ikonky; tečky v týdenním pruhu ukazují dodržení.
- **Ikona:** kalendářový list s tabletou.
- **Pro:** nejlepší přehled o historii a budoucnosti, pro lidi s mnoha léky a měnícím se plánem; kontrola zásob a historie jsou „přirozeně“ po ruce.
- **Proti:** potvrzení není první věc na obrazovce; nejvíc vlastního UI (časová osa), na iPhone hustší; nejhůř se převádí do widgetu.
- **Vhodné pro:** pečující osoby, uživatele s komplikovaným režimem.
- **Pracnost:** vysoká.

### Srovnání

| | A Klinicky čistý | B Lékárnička | C Jistota | D Plánovač |
|---|---|---|---|---|
| První na obrazovce | seznam dnešních dávek | karty dávek | jedna velká dávka + tlačítko | denní časová osa |
| Řeší „zapomněl jsem?“ | dobře | dobře | nejlépe | průměrně |
| Osobnost | nízká | vysoká | střední | střední |
| Práce na Mac/iPad | minimální | větší | malá | velká |
| Přenos do widgetu | snadný | střední | nejsnazší (stejná karta) | obtížný |
| Pracnost celkem | nízká | střední | nízká–střední | vysoká |

---

## 3. Rozhodnutí

**Rozhodnuto 6. 11. 2026: směr C „Jistota“ na nativním základu směru A.** Vizuální návrhy všech čtyř směrů: https://claude.ai/artifact/42xwhq6dkUWkqEwC9V3ZP5

**Směr C „Jistota“ na nativním základu směru A.** Obrazovka Dnes dostane velkou kartu nejbližší dávky s obřím tlačítkem a miniaturou tablety; Historie, Léky a Nastavení zůstanou systémové seznamy. Tím se nejlépe pokryje hlavní cíl ze specifikace (uživatel má vždy jistotu, že dávku vzal) za malou cenu, a stejná karta poslouží jako widget ve fázi 7. Pokud se později ukáže, že aplikace potřebuje víc osobnosti pro App Store, dá se na kartu a ikonu přidat teplejší paleta ze směru B, aniž by se měnila struktura.

Název: Vzato / vzato.app (kapitola 1), čeká jen na kontrolu ochranných známek.
