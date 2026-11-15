# Moja przestrzeń

Prywatna aplikacja SwiftUI na iPhone’a. Minimalna wersja systemu to iOS 16.0. Na iPhonie 13 sprawdzisz swoją wersję w **Ustawienia → Ogólne → To urządzenie**.

## Pierwsze wydanie z Windowsa

Utwórz na GitHubie osobne **prywatne, puste** repozytorium `moja-przestrzen`. Rozpakuj paczkę i otwórz Git Bash w katalogu z `MojaPrzestrzen.xcodeproj`. Zamień `TWOJ_LOGIN` w adresie poniżej.

```bash
git init -b main
git add .
git commit -m "Pierwsza wersja Mojej przestrzeni"
git remote add origin https://github.com/TWOJ_LOGIN/moja-przestrzen.git
git tag v0.1.0
git push --atomic -u origin main v0.1.0
```

GitHub Actions buduje aplikację w trybie Release na `macos-15` dla fizycznych urządzeń ARM64. Po wypchnięciu taga `vMAJOR.MINOR.PATCH` udana kompilacja automatycznie tworzy wydanie w **Releases** i załącza niepodpisany plik `MojaPrzestrzen-MAJOR.MINOR.PATCH.ipa`. Wypychanie kodu na `main` lub ręczne uruchomienie workflow pozwala pobrać paczkę również w **Actions → iOS IPA → Artifacts → MojaPrzestrzen-IPA**. Z artefaktu Actions trzeba najpierw wypakować plik `.ipa`.

Kolejne wydanie powstaje po zmianie `MARKETING_VERSION` w projekcie Xcode i scaleniu jej z `main` albo po wypchnięciu nowego taga `vMAJOR.MINOR.PATCH`. Tag powinien wskazywać commit zawierający workflow. Pull request uruchamia kompilację testową i udostępnia IPA jako artefakt. Prywatne repozytorium korzysta z limitu GitHub Actions przypisanego do konta. Kompilacja nie wymaga sekretów Apple ani Maca użytkownika.

## SideStore i aktualizacje

1. Pobierz IPA z **Releases → Assets** i zapisz ją w **Plikach** na iPhonie.
2. Połącz iPhone’a z Wi-Fi, włącz VPN używany przez SideStore i wybierz w SideStore **My Apps → +**. Wskaż pobraną IPA. SideStore podpisze i zainstaluje aplikację przy użyciu Twojego konta Apple.
3. Uruchom **Moja przestrzeń** z ekranu początkowego. Codzienne korzystanie działa w trybie samolotowym. VPN potrzebny jest w SideStore przy instalowaniu, aktualizowaniu lub odświeżaniu podpisu.
4. Odświeżaj aplikację w SideStore przed końcem 7-dniowego okresu podpisu. Bezpłatne konto podlega też limitowi aktywnych aplikacji.
5. Przed pierwszą aktualizacją wyeksportuj kopię w **Archiwum → Eksportuj kopię JSON**. Zainstaluj nowszą IPA w SideStore na tym samym koncie Apple, bez usuwania istniejącej aplikacji. Stały identyfikator źródłowy to `pl.dawidp.mojaprzestrzen`. SideStore może zmodyfikować efektywny identyfikator podczas podpisu, więc do zachowania kontenera potrzebna jest również ta sama tożsamość podpisywania i aktualizacja w miejscu.

LiveContainer jest opcjonalny. Dane z testu w LiveContainer pozostają w jego odrębnym kontenerze. Można je przenieść za pomocą kopii JSON.

[Instrukcja SideStore](https://docs.sidestore.io/docs/installation/prerequisites.html) · [FAQ SideStore](https://docs.sidestore.io/docs/faq.html)

## Dane i archiwum

Lokalny zapis jest atomowy, w katalogu Application Support aplikacji. Eksport to pojedynczy JSON z polami `format` (`pl.dawidp.mojaprzestrzen.backup`), `version` (obecnie 1), `duties` oraz `notes`. Daty są zakodowane jako sekundy względem epoki Foundation (1 stycznia 2001, UTC). Zapisz kopię w Plikach poza kontenerem aplikacji. Import sprawdza format, wersję i spójność historii, następnie prosi o potwierdzenie zastąpienia aktualnych danych.

Historia stałych obowiązków jest odtwarzana po okresach w strefie Europe/Warsaw. Po edycji stałego obowiązku jego nowa wersja obowiązuje w bieżącym i kolejnych okresach, a zamknięte okresy nadal pokazują wcześniejsze wersje. Archiwum dni i tygodni służy do odczytu. Problem usunięty z „Do przespania” znika z kopii tworzonych po jego usunięciu.

## Sprawdzenie na iPhonie 13

Sprawdź gest w dół z tytułu, przewijanie długiej listy i przesunięcie w lewo na wierszu w „Do przespania”. Poza listą przesuwanie po nagłówku lub dolnym pasku zmienia segment. Następnie dodaj testowy wpis w trybie samolotowym, zamknij i ponownie uruchom aplikację. Wyeksportuj wpis do Plików i sprawdź jego odtworzenie. Przy wydaniu `v0.1.1` zainstaluj IPA nad `v0.1.0` i sprawdź, czy wpis jest nadal dostępny.
