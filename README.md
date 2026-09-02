# EduDeploy

**EduDeploy** on Windowsille suunniteltu keskitetty ohjelmistojen asennustyökalu 3D-, CAD- ja muiden opiskelussa tarvittavien ohjelmistojen asentamiseen.

Tavoitteena on tehdä ohjelmistojen asentamisesta opiskelijalle mahdollisimman helppoa: ohjelma avataan, haluttu sovellus valitaan ja asennus käynnistetään yhdestä paikasta.

## ✨ Ominaisuudet

* 🖥️ Windows-käyttöliittymä
* 📦 Ohjelmien lataaminen ja asentaminen yhdestä paikasta
* 🔧 MSI- ja EXE-asentajien tuki
* 🌐 Lataussivujen avaaminen ohjelmille, joiden automaattista asennusta ei vielä tueta
* 📁 Asennustiedostojen väliaikainen tallennus `%TEMP%\EduDeploy`-kansioon
* 🔐 Asennusten käynnistäminen järjestelmänvalvojan oikeuksilla
* 📝 MSI-asennusten lokitiedostot ongelmatilanteita varten
* 🗂️ Ohjelmien ryhmittely kategorioihin
* ⚙️ Ohjelmien tiedot määritellään `config.json`-tiedostossa

## 🛠️ Tällä hetkellä tuetut ohjelmat

| Ohjelma         | Kategoria | Versio | Asennustapa |
| --------------- | --------- | -----: | ----------- |
| Blender         | 3D        | 4.5.13 | MSI         |
| Autodesk Fusion | CAD       |   2026 | Lataussivu  |
| Rhino           | 3D        |      8 | Lataussivu  |
| SolidWorks      | CAD       |   2026 | Lataussivu  |

> Ohjelmien versiot ja latausosoitteet määritellään `config.json`-tiedostossa.

## 📁 Projektin rakenne

```text
EduDeploy/
│
├── EduDeploy.ps1
├── config.json
└── README.md
```

## 🚀 Käynnistäminen

EduDeploy voidaan käynnistää PowerShellillä:

```powershell
powershell -ExecutionPolicy Bypass -File .\EduDeploy.ps1
```

### Suositeltu kansiorakenne

```text
C:\EduDeploy\
├── EduDeploy.ps1
├── config.json
└── README.md
```

## ⚙️ Configuration

Ohjelmat määritellään `config.json`-tiedostossa.

Esimerkiksi Blender:

```json
{
  "name": "Blender",
  "description": "3D-mallinnus, animaatio ja renderöinti",
  "category": "3D",
  "version": "4.5.13",
  "downloadUrl": "https://download.blender.org/release/Blender4.5/blender-4.5.13-windows-x64.msi",
  "installerType": "msi",
  "installerArguments": "/qn /norestart",
  "installedCheck": "blender.exe"
}
```

### Installer-tyypit

EduDeploy tukee tällä hetkellä seuraavia asennustyyppejä:

* `msi` – lataa MSI:n ja asentaa sen automaattisesti
* `exe` – lataa EXE-asentajan ja käynnistää sen
* `website` – avaa ohjelman lataussivun selaimessa

## 📦 Väliaikaiset tiedostot

Ladatut asennustiedostot tallennetaan:

```text
%TEMP%\EduDeploy\
```

Esimerkiksi Blender:

```text
%TEMP%\EduDeploy\Blender.msi
```

MSI-asennuksesta syntyvä loki:

```text
%TEMP%\EduDeploy\Blender-install.log
```

Lokia voidaan käyttää MSI-asennuksen vianmääritykseen.

## 🔐 Järjestelmänvalvojan oikeudet

Ohjelmistojen asennukset suoritetaan Windowsin järjestelmänvalvojan oikeuksilla.

Windows näyttää tarvittaessa UAC-vahvistuksen ennen asennusta.

## 🧪 Kehitystilanne

### v0.1

* Ensimmäinen käyttöliittymä
* Kategoriat
* Ohjelmakortit
* Perusrakenne

### v0.2

* Blenderin MSI-lataus
* MSI-asennus `%TEMP%\EduDeploy`-kansiosta
* Järjestelmänvalvojan oikeudet
* MSI-asennuksen lokitus
* Blenderin onnistunut asennus

### v0.3

* Yleinen asennusjärjestelmä
* MSI-tuki
* EXE-tuki
* Website-tuki
* Asennustavan määrittely `config.json`-tiedostossa
* Blender ei enää tarvitse omaa erillistä asennuskoodia

## 🗺️ Tulevaisuus

Suunniteltuja ominaisuuksia:

* [ ] Automaattinen asennuksen tunnistus
* [ ] `ASENNETTU`-tila ohjelman käynnistyessä
* [ ] Parempi latauksen etenemispalkki
* [ ] Latausnopeuden ja etenemisen näyttäminen
* [ ] Lisää 3D- ja CAD-ohjelmia
* [ ] Parempi EXE-asentajien tuki
* [ ] Ohjelmien päivitysten hallinta
* [ ] Opiskelijakohtainen kirjautuminen
* [ ] Keskitetty ohjelmistojen hallinta
* [ ] Valmis Windows-jakelupaketti

## 🎓 Projektin tavoite

EduDeployn tavoitteena on tarjota oppilaitoksille helppo tapa jakaa ja asentaa opiskelijoiden tarvitsemat ohjelmistot ilman, että jokainen ohjelma täytyy etsiä ja asentaa erikseen.

Opiskelijan näkökulmasta prosessin pitäisi olla mahdollisimman yksinkertainen:

```text
Avaa EduDeploy
      ↓
Valitse ohjelma
      ↓
Paina ASENNA
      ↓
EduDeploy lataa ohjelman
      ↓
EduDeploy asentaa ohjelman
      ↓
Valmis
```

## 📄 License

License: All rights reserved. The source code is publicly available for viewing and educational purposes. Redistribution, modification or commercial use is not permitted without permission from the author.
