

# M1 Windows AD — Livrables

Livrables du groupe pour le module **Windows Server / Active Directory** (M1). Le fil rouge est l'infrastructure de **NovaCorp** : un domaine `novacorp.test` monté sur quatre machines virtuelles hébergées sur quatre PC différents, puis administré de bout en bout (identités, droits, GPO, réplication, sécurité, automatisation, dépannage).

Les énoncés sont dans le dépôt du formateur : [labs](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs).

## Groupe

| Membre | VM hébergée |
|---|---|
| Axel Martinez | `CLT01` |
| Julien Zielona | `DC02` |
| Leo Scholl | `DC01` |
| Yann Compin | `SRV01` |

## Environnement

Domaine `novacorp.test` (NetBIOS `NOVACORP`), réseau du groupe `10.100.12.0/24` en mode Bridged.

| VM | IP | Rôle |
|---|---|---|
| `DC01` | `10.100.12.11` | Premier contrôleur de domaine, DNS intégré à AD |
| `DC02` | `10.100.12.12` | Second contrôleur de domaine, DNS |
| `CLT01` | `10.100.12.13` | Poste client Windows |
| `SRV01` | `10.100.12.14` | Serveur membre, serveur de fichiers (`D:\Shares`) |

## Index des TP

| TP | Sujet | Énoncé | Livrables |
|---|---|---|---|
| **TP00** | Preflight : réseau entre les PC de l'équipe | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP00-PREFLIGHT) | [Cartographie et validation réseau](TP00/TP00%20AD.md) · [Configuration de SRV01](TP00/TP00_SRV01.md) |
| **TP01** | Construire le domaine NovaCorp | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP01-AD-FOUNDATIONS) | [Livrable DC01](TP01/TP1-Livrable_DC01.md) · [Initialize-NovaCorpOU.ps1](TP01/Initialize-NovaCorpOU%201.ps1) · [import-users.ps1](TP01/import-users.ps1) |
| **TP02** | Identités, RBAC, AGDLP et File Server | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP02-IDENTITY-RBAC) | [Livrable TP02](TP02/TP02_livrable) (matrice d'accès, setup, vérifications, délégation Helpdesk) |
| **TP03** | DNS, DC Locator, Kerberos et SPN | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP03-DNS-KERBEROS) | [Livrable TP03](TP03/TP3-Livrable.md) |
| **TP04** | GPO avancées et troubleshooting | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP04-GPO) | [Livrable TP04](TP04-GPO/TP04.md) · [rapports HTML (GPO et gpresult)](TP04-GPO/html) |
| **TP05** | Deuxième DC, réplication et sites AD | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP05-MULTIDC-REPLICATION) | [Livrable TP05](TP05/TP05_AD.md) (réplication, sites, FSMO) |
| **TP06** | Sécurité et récupération | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP06-SECURITY-RECOVERY) | [Livrable TP06](TP06/TP6-Livrable.md) (corbeille AD, PSO, audit des comptes privilégiés, gMSA) |
| **TP07** | Administrer NovaCorp comme du code | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/TP07-AUTOMATION) | [Dossier TP07](TP07_WindowsAD_Scripts/) · [README](TP07_WindowsAD_Scripts/README.md) · [Deploy-NovaCorp.ps1](TP07_WindowsAD_Scripts/scripts/Deploy-NovaCorp.ps1) · [Test-NovaCorp.ps1](TP07_WindowsAD_Scripts/scripts/Test-NovaCorp.ps1) · [Install-NovaCorpAD.ps1](TP07_WindowsAD_Scripts/scripts/Install-NovaCorpAD.ps1) |
| **TP08** | Final Boss : incident d'infrastructure | [énoncé](https://github.com/Guiteguit/M1_Windows_AD/tree/main/labs/FINAL-BOSS) | [Rapport d'incident](TP08_FinalBoss/TP08_FinalBoss.md) |

## Organisation du dépôt

```text
.
├── TP00/                     réseau, cartographie
├── TP01/                     promotion du domaine, OU, import des utilisateurs
├── TP02/                     AGDLP, partages, délégation Helpdesk
├── TP03/                     DNS, Kerberos, SPN
├── TP04-GPO/                 GPO et rapports HTML
├── TP05/                     réplication, sites, FSMO
├── TP06/                     corbeille, PSO, audit, gMSA
├── TP07_WindowsAD_Scripts/   scripts Deploy / Test / Install et jeux de données
└── TP08_FinalBoss/           rapport d'incident
```

## Notes

- Les rapports HTML du TP04 (`GPO-*.html`, `gpresult-*.html`) s'ouvrent dans un navigateur après téléchargement ; GitHub n'en affiche que le code source.
- Les scripts du TP07 ont leur propre [README](TP07_WindowsAD_Scripts/README.md) (déroulé, paramètres, format du CSV).
- Les rôles ont tourné d'un TP à l'autre, comme le prévoient les énoncés.