# Zadanie dla Claude Code: natywny Android na Radxa Dragon Q6A (boot z karty SD)

> Wklej ten plik do Claude Code jako brief projektu. Jest napisany tak, by Claude Code mógł go traktować jako specyfikację: są tu cele, znane fakty, ograniczenia, podział na fazy z konkretnymi deliverables oraz format raportowania. Czytaj sekcję „JAK PRACUJEMY" zanim zaczniesz.

---

## CEL

Zbudować **natywny Android 13** (nie Waydroid, nie kontener) uruchamiany z **karty microSD** na **Radxa Dragon Q6A** (SoC Qualcomm QCS6490, GPU Adreno 643), z **działającą akceleracją GPU 3D**. Waydroid z GPU już działa na Radxa OS — to jest następny krok, „prawdziwy" Android jako jedyny system.

## ŚRODOWISKO PRACY (mój sprzęt) — ZWERYFIKUJ TO ZANIM COKOLWIEK POBIERZESZ

Maszyna build: **Dell G15 5530, 32 GB RAM, 1 TB NVMe, Windows.** Claude Code działa w **WSL2 / Ubuntu 22.04** (osobna instalacja od ewentualnego Claude Code w PowerShell — pracujemy wyłącznie w WSL).

**Twój pierwszy obowiązek (checklist przed `repo sync`):**
```bash
pwd                       # MUSI być pod /home/<user>/... — czyli natywny FS WSL2
df -h .                   # wolne miejsce: build AOSP potrzebuje ~400 GB
free -g                   # RAM (mam 32 GB); jeśli build pada na OOM, ogranicz wątki (make -jN)
nproc                     # liczba rdzeni do równoległego buildu
ping -c1 github.com       # sieć działa? (WSL2 dziedziczy WiFi z Windows automatycznie)
```
**TWARDA ZASADA — wydajność FS:** cały build (źródła, out) MUSI leżeć w natywnym FS WSL2 (`~/q6a/...`). **NIGDY nie buduj na `/mnt/c/...`** — praca na dysku Windows przez WSL2 jest skrajnie wolna i build albo będzie trwał dobę, albo padnie. Jeśli wykryjesz, że `pwd` pokazuje `/mnt/c`, **zatrzymaj się i każ mi przejść do `~/`**.

Moje materiały źródłowe (FlatBuild Rubik Pi, provision) są na dysku Windows; skopiuję je raz do `~/q6a/rubikpi-flatbuild/` i stamtąd ich używasz.

**Granica WSL2 ↔ sprzęt:** WSL2 służy do BUDOWANIA obrazu. Flashowanie karty SD i konsola UART idą po stronie Windows (Etcher / PuTTY), bo WSL2 nie ma domyślnie dostępu do USB/czytnika kart. Model: **WSL2 = fabryka obrazu (Ty), Windows = narzędzia do płytki, ja = łącznik.** Gdy dojdziemy do flashowania, generuj `.img` w `~/q6a/...` i każ mi skopiować go na dysk Windows do wgrania Etcherem (albo poprowadź podłączenie USB do WSL przez `usbipd-win`).

## KONTEKST SPRZĘTOWY (fakty ustalone, nie podważaj bez powodu)

- **SoC:** QCS6490, ten sam co w Rubik Pi 3 i pokrewny QCM6490 z Fairphone 5. GPU Adreno 643 — architektura a6xx, wspierana przez otwarty Mesa **Turnip** (Vulkan) / **Freedreno** (GLES).
- **Boot Q6A ≠ boot Rubik Pi.** Q6A ma firmware **UEFI na osobnej kości SPI**, który inicjalizuje sprzęt (CPU→RAM→storage) i ładuje kernel z dowolnego nośnika (SD/USB/eMMC/NVMe) jak PC. Rubik Pi startuje „po telefonowemu" (firehose→UFS, ABL→Android boot.img). **Dlatego pakietu FlatBuild Rubik Pi NIE da się przenieść 1:1.**
- **Mainline Linux na Q6A już działa** z DTB `qcs6490-radxa-dragon-q6a.dtb`: Ethernet (RTL8111K/r8169), GPU (Turnip), enkoder/dekoder wideo (Venus), oba DSP (ADSP+CDSP), eMMC/SD/M.2, USB. To nasz fundament kernela.
- **WiFi/BT (Quectel FCU760K = chipset AIC8800 po USB)** — sterowniki out-of-tree, trudne. **NIEISTOTNE dla gier. Sieć = Ethernet.** Odkładamy na sam koniec lub pomijamy.
- **Userdebug FlatBuild Rubik Pi** mamy lokalnie — przydaje się jako źródło **blobów userspace Adreno** (`super_*.img`) jako plan B wobec Turnip. Firmware niskopoziomowy (xbl/abl/aop/devcfg, rawprogram, layout UFS) z tego pakietu **NIE jest używany** (inny model bootu).

## ŚCIEŻKA REKOMENDOWANA: GloDroid jako baza

Zamiast budować AOSP+device tree od zera, bazujemy na **GloDroid** (github.com/GloDroid/glodroid_manifest) — to AOSP dla SBC z gotowym mainline-owym podejściem: Mesa/Turnip, `drm_hwcomposer`, `minigbm`, tryb headless, build obrazu na SD. GloDroid **nie ma** gotowego targetu QCS6490 — naszą pracą jest dodać nowy target/urządzenie `dragon_q6a`. To znacznie mniej pracy niż czysty AOSP, bo cały glue (gralloc/HWC/EGL pod DRM/KMS) jest już rozwiązany dla innych płyt.

> Alternatywa do rozważenia w Fazie 0: repo `GloDroidCommunity/qcom-msm8916-series` pokazuje wzorzec „GloDroid + mainline kernel Qualcomma + lk2nd". Architektura msm8916 jest inna, ale **wzorzec integracji Qualcomm↔GloDroid** jest wprost przydatny jako szablon.

---

## JAK PRACUJEMY (przeczytaj uważnie)

1. **Ty (Claude Code) jesteś inżynierem od kodu i buildów. Ja jestem Twoimi rękami i oczami przy płytce.** Nie masz fizycznego dostępu do Q6A: nie włożysz karty SD, nie wciśniesz EDL, nie podłączysz UART, nie zobaczysz diody/HDMI. Wszystko, co wymaga sprzętu, opisujesz mnie krok po kroku, a ja wklejam Ci wynik (logi UART, `dmesg`, zachowanie diod).
2. **Pętla pracy:** proponujesz zmianę → budujesz/generujesz pliki → dajesz mi dokładną komendę flashowania i co mam obserwować → ja wracam z logiem → diagnozujesz → poprawka. Po każdej iteracji aktualizuj `PROGRESS.md`.
3. **Działaj fazami. Nie przeskakuj.** Każda faza ma „Definition of Done". Nie ruszaj kolejnej, dopóki ja nie potwierdzę DoD na realnym sprzęcie.
4. **Sieć bezpieczeństwa:** wszystko robimy z karty SD. Firmware UEFI na SPI **zostaje nietknięty** — jak obraz nie wstanie, wyjmuję kartę i poprawiamy na PC. Nie proponuj żadnych operacji dotykających firmware SPI ani trybu EDL, dopóki wyraźnie nie poproszę. Jeśli kiedykolwiek zaproponujesz coś, co może nadpisać SPI/firmware, **najpierw mnie ostrzeż wielką czcionką i poczekaj na zgodę.**
5. **Każdą komendę, którą mam wykonać na Q6A lub na moim PC, podawaj w osobnym bloku, z jednym celem i komentarzem co robi.** Zakładaj, że jestem mniej zaawansowany — opisuj też jak wejść w UART/jakie diody obserwować.
6. **Nie wymyślaj faktów o sprzęcie.** Jak czegoś nie wiesz (np. dokładny `compatible` węzła, offset partycji), powiedz to wprost i zaproponuj, jak to ustalić z mojego działającego Radxa OS (mam je na SD i mogę z niego czytać `/proc/device-tree`, `dmesg`, `/sys`).

---

## ŹRÓDŁA PRAWDY O SPRZĘCIE (mam do nich dostęp, proś mnie o zrzuty)

Z mojego **działającego Radxa OS na Q6A** mogę dostarczyć Ci:
- `dtc -I fs -O dts /sys/firmware/devicetree/base -o live.dts` — realny, bootujący device tree.
- `cat /proc/device-tree/model`, `.../compatible`
- `dmesg`, `lsblk`, `cat /proc/cmdline`, zawartość partycji EFI (`/boot`, `loader/entries/*.conf`, `*.dtb`)
- `vulkaninfo`, `glxinfo`, `weston-info` — potwierdzenie, że Turnip działa i z jakimi parametrami.
- wersję kernela (`uname -r`), konfig (`/proc/config.gz` jeśli jest).

Z **pakietu FlatBuild Rubik Pi** (lokalnie na PC) mogę dostarczyć:
- bloby userspace Adreno wyciągnięte z `super_*.img` (do planu B zamiast Turnip).
- listę plików / dowolny plik na żądanie.

---

## FAZY

### FAZA 0 — Rekonesans i wybór architektury (bez flashowania)
**Działania Claude Code:**
- Poproś mnie o: `live.dts`, `uname -r`, `/proc/cmdline`, listing partycji EFI z działającego Radxa OS, output `vulkaninfo`.
- Ustal: jaki bootloader EFI używa Radxa (systemd-boot? grub?), jak wygląda wpis bootujący, gdzie leży DTB, jaki cmdline.
- Zdecyduj architekturę docelową obrazu SD (patrz Faza 4) i opisz ją w `ARCHITECTURE.md`.
- Zbuduj środowisko: instrukcja przygotowania maszyny build (Ubuntu 22.04, zależności AOSP/GloDroid, miejsce na dysku ~400 GB, `repo`).
**Definition of Done:** mamy `ARCHITECTURE.md` z jasną decyzją „jak Android wystartuje z SD na tym konkretnym UEFI", oparty na realnym `live.dts` i wpisie bootloadera Radxa.

### FAZA 1 — Build bazowego GloDroid + nowy target `dragon_q6a`
**Działania:**
- `repo init`/`sync` GloDroid; build dla najbliższej istniejącej płyty Qualcomm/ARM64 jako sanity-check toolchaina.
- Utwórz szkielet device target `device/glodroid/dragon_q6a` (kopiuj wzorzec z istniejącego targetu + integracja Qualcomm wg qcom-msm8916-series).
- Wkomponuj **kernel mainline z DTB Q6A** (`qcs6490-radxa-dragon-q6a`) do build-flow GloDroid (AOSPEXT / external kernel). Włącz w defconfig to, co potrzebne: DRM/MSM, Turnip-friendly, r8169, USB, MMC/SD, binder/ashmem, ANDROID_*; CONFIG dla Androida (selinux, etc.).
**DoD:** `make` produkuje obraz SD (`.img`) dla targetu `dragon_q6a` bez błędów; kernel z właściwym DTB jest w obrazie. (Jeszcze nie bootujemy „na serio".)

### FAZA 2 — Pierwszy boot do logu, bez wymagań na ekran
> **STAN NARZĘDZI: NIE MAM jeszcze kabla USB–UART.** Płytka ma dedykowane wyjście **UART0** do konsoli (Radxa to dokumentuje), brakuje tylko adaptera (CP2102/CH340, ~20 zł, podłączasz GND/TX/RX, NIE czerwony przewód; w Windows PuTTY/Tabby). Zamawiam go równolegle. Dlatego Faza 2 ma dwa tryby — Ty zaproponuj, którym idziemy, zależnie od tego, czy kabel już dotarł:
>
> **Tryb A (z kablem UART — preferowany):** pełna konsola od startu UEFI. Dasz mi piny na 40-pin, baud i ustawienia PuTTY, ja wkleję log.
>
> **Tryb B (bez kabla — diagnostyka „po objawach" + ADB po sieci):** opieramy się na (1) stanie diod (zielona=zasilanie, niebieska miga=boot trwa), (2) zachowaniu HDMI, (3) **ADB po Ethernecie** — jeśli boot dojdzie do sieci+adbd, daj mi `adb connect <ip>`, `adb logcat`, `adb shell dmesg`, co zastępuje UART. **Świadome ryzyko trybu B:** jeśli boot padnie PRZED uruchomieniem sieci, lecimy w ciemno (brak widoczności wczesnej fazy UEFI/kernela). Dlatego w trybie B projektuj obraz defensywnie: maksymalnie gadatliwy boot, wczesne uruchomienie sieci/adbd, ewentualnie zapis logu kernela na partycję odczytywalną po wyjęciu karty SD do PC.

**Działania:**
- Dasz mi: dokładną komendę zapisu obrazu na SD (przez Etcher na Windows lub `dd` — patrz sekcja ŚRODOWISKO), oraz — zależnie od trybu — albo instrukcję UART (Tryb A), albo plan diagnostyki ADB/diody (Tryb B).
- Cel pierwszego bootu: **kernel rusza i dochodzi do userspace** (tryb headless GloDroid to wspiera). Nie wymagamy jeszcze HDMI.
- Diagnozujesz: czy UEFI załadował kernel+DTB, czy kernel mountuje rootfs z SD, gdzie się zatrzymuje.
**DoD:** mamy dowód (log UART **lub** logcat/dmesg po sieci), że kernel Androida startuje i dochodzi do init/userspace. To **najważniejszy kamień milowy całego projektu.** Jeśli jesteśmy w trybie B i utykamy na „cichym" padnięciu — to jest sygnał, że trzeba poczekać na kabel UART; powiedz mi to wprost zamiast zgadywać w nieskończoność.

### FAZA 3 — GPU + wyświetlanie (HDMI)
**Działania:**
- Doprowadź `drm_hwcomposer` + Mesa Turnip do działania na DPU QCS6490 (KMS). Ustal właściwe connector/encoder dla HDMI z `live.dts`.
- Walidacja: `dumpsys SurfaceFlinger`, renderer = Adreno/Turnip; uruchomienie launchera na HDMI.
- Test 3D: aplikacja Vulkan/GLES (np. prosty benchmark), potwierdzenie akceleracji.
**DoD:** Android rysuje UI na HDMI z akceleracją GPU; prosty test 3D renderuje na Adreno przez Turnip. **To realizacja głównego celu (Android + GPU 3D).**

### FAZA 4 — Stabilizacja obrazu SD i bootloadera
**Działania:**
- Dopracuj layout obrazu SD: partycja **EFI (FAT)** z bootloaderem EFI + kernel + DTB + cmdline, partycje Androida (`system`/`vendor`/`userdata` lub super + dynamic). Wzoruj się na tym, jak Radxa OS układa EFI (z Fazy 0).
- Upewnij się, że obraz jest „dd-owalny" i powtarzalny (`make sdcard`/wic).
- AVB: na czas bring-up wyłączone; udokumentuj.
**DoD:** czysty zapis obrazu na nową kartę → boot do działającego Androida z GPU, powtarzalnie.

### FAZA 5 — Peryferia (kolejność wg zwrotu)
1. **Ethernet** (r8169) — sieć, ADB po TCP. 2. **Audio** (HDMI audio / jack, HAL + mixer). 3. **USB** (host, pady do gier). 4. **Termika/perf** (cpufreq, GPU governor, throttling). 5. **Storage perf**.
**DoD per peryferium:** działa i jest odnotowane w `PROGRESS.md`.

### FAZA 6 (opcjonalna) — WiFi/BT (AIC8800)
Tylko jeśli zechcę. Integracja out-of-tree sterownika AIC8800 (USB) + firmware + HAL. Wysokie ryzyko, zerowy wpływ na gaming po Ethernecie.

---

## DELIVERABLES (utrzymuj w repo projektu)
- `ARCHITECTURE.md` — decyzja o bootowaniu z SD na UEFI Q6A (Faza 0).
- `PROGRESS.md` — log iteracji: data, co próbowaliśmy, log, wynik, następny krok.
- `device/glodroid/dragon_q6a/` — target.
- `flash_sd.sh` — skrypt zapisu obrazu na kartę z zabezpieczeniem przed pomyłką dysku.
- `BUILD.md` — jak postawić środowisko i zbudować od zera.
- `TESTING.md` — komendy walidacji GPU/3D, audio, sieci.

## FORMAT TWOICH ODPOWIEDZI W TRAKCIE
W każdej iteracji trzymaj się schematu:
1. **Cel tej iteracji** (1 zdanie).
2. **Co zmieniam w kodzie/buildzie** (pliki + diff/komendy buildu).
3. **Co mam zrobić przy płytce** (krok po kroku: zapis SD, UART, diody, co obserwować).
4. **Czego oczekujemy / jak poznać sukces.**
5. **Co wkleić Ci z powrotem** (konkretny log/komenda).
Na końcu zaktualizuj `PROGRESS.md`.

## PIERWSZY KROK (zrób teraz)
Nie pisz całego planu od nowa. Wykonaj w tej kolejności:
1. **Zweryfikuj środowisko** wg sekcji ŚRODOWISKO (checklist: `pwd` w natywnym FS WSL2, `df -h`, `free -g`, sieć). Jeśli coś nie gra (zwłaszcza praca na `/mnt/c` albo za mało miejsca) — zatrzymaj się i powiedz mi.
2. Zacznij **Fazę 0**: wypisz dokładną listę zrzutów, których potrzebujesz z mojego działającego Radxa OS na Q6A (gotowe komendy do skopiowania), oraz dokończ przygotowanie maszyny build.
3. Odnotuj status narzędzi sprzętowych: **nie mam jeszcze kabla UART** (zamawiam). Zaplanuj Fazy 0–1 tak, by go nie wymagały, i przypomnij mi przed Fazą 2, czy kabel już dotarł (Tryb A vs B).
Poczekaj na moje dane, zanim przejdziesz dalej.

---

### Realistyczne oczekiwania (żeby było uczciwie)
To projekt na tygodnie, nie na wieczór. Najtrudniejsze i obarczone ryzykiem są: Faza 2 (pierwszy boot — dopasowanie UEFI↔kernel↔DTB↔rootfs na SD) i Faza 3 (HWC/KMS na DPU Qualcomma). GPU compute/render sam w sobie jest „łatwy" (Turnip już działa na tym SoC pod Linuksem) — trudność leży w integracji warstwy wyświetlania Androida, nie w samym GPU. Jeśli na którymś etapie utkniemy twardo, mam plan B: bloby Adreno z FlatBuild zamiast Turnip. Brak kabla UART nie blokuje Faz 0–1; w Fazie 2 bez niego diagnostyka jest możliwa, ale częściowo „ślepa" (patrz Tryb B) — dlatego kabel warto mieć przed pierwszym bootem.
