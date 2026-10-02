# M1 Windows AD Scripts — NovaCorp (TP07)

README : généré en partie par IA (Gemini-Pro) : peut contenir des erreurs.

Scripts PowerShell pour monter et peupler l'annuaire Active Directory de NovaCorp à partir d'un fichier CSV, puis en contrôler la conformité.

| Script | Rôle | Modifie l'AD ? |
|---|---|---|
| `Install-NovaCorpAD.ps1` | Installe le rôle AD DS et crée la forêt `novacorp.test` | Oui (une seule fois) |
| `Deploy-NovaCorp.ps1` | Crée et maintient OU, groupes, utilisateurs et appartenances | Oui (idempotent) |
| `Test-NovaCorp.ps1` | Contrôle la conformité de l'annuaire | Non (lecture seule) |

>  `Install-NovaCorpAD.ps1` crée une **nouvelle forêt**. À n'utiliser que sur un serveur de labo isolé, jamais en production.

---

## Arborescence

```
M1_Windows_AD_Scripts/
├── datasets/
│   └── employees.csv          # source des utilisateurs
├── scripts/
│   ├── Install-NovaCorpAD.ps1
│   ├── Deploy-NovaCorp.ps1
│   ├── Test-NovaCorp.ps1
│   └── logs/                  # créé automatiquement (journaux)
└── README.md
```

Les scripts cherchent le CSV dans `..\datasets\employees.csv` par rapport à leur propre dossier : **conserver cette arborescence**, ou passer le chemin avec `-CsvPath`.

---

## Prérequis

- Windows Server (testé sur Windows Server avec Windows PowerShell 5.1).
- Session **administrateur**.
- Une VM de labo sur un **réseau isolé**, avec un **snapshot** avant chaque étape importante.
- Lancer les scripts depuis une **console PowerShell** .

---

## Déroulé complet

### 1. Récupérer les scripts sur le serveur

Si la VM a accès à Internet :

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
Invoke-WebRequest https://github.com/Naxyrius/M1_Windows_AD_Scripts/archive/refs/heads/main.zip -OutFile $env:TEMP\scripts.zip
Expand-Archive $env:TEMP\scripts.zip -DestinationPath C:\TP -Force
Get-ChildItem C:\TP -Recurse | Unblock-File
cd C:\TP\M1_Windows_AD_Scripts-main\scripts
```

Sinon, télécharger le ZIP sur un autre poste et le copier sur la VM (glisser-déposer, dossier partagé VMware).

`Unblock-File` est indispensable : les fichiers téléchargés sont marqués comme venant d'Internet et PowerShell peut refuser de les exécuter.

### 2. Préparer le serveur (avant la promotion)

Adapter les adresses au réseau du labo, et le nom de la carte (voir `Get-NetAdapter`) :

```powershell
# IP fixe
Set-NetIPInterface -InterfaceAlias "Ethernet0" -Dhcp Disabled
New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.10.10 -PrefixLength 24 -DefaultGateway 192.168.10.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 127.0.0.1

# Nom du serveur (redémarre)
Rename-Computer -NewName SRVTEST -Restart
```

Un contrôleur de domaine doit avoir **une seule carte réseau active** et une **IP fixe**. Le renommage est à faire **avant** la promotion.



### 3. Installer AD DS et créer la forêt

Dans le dossier `scripts` :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-NovaCorpAD.ps1 -WhatIf     # simulation : vérifie les prérequis
.\Install-NovaCorpAD.ps1             # installation réelle
```

- Le mot de passe **DSRM** (mode restauration des services d'annuaire) est demandé en saisie masquée : le noter.
- Les avertissements sur la **délégation DNS** sont normaux pour une première forêt.
- L'étape « installation du service DNS » peut durer plusieurs minutes.
- Le serveur **redémarre automatiquement**.

Après le redémarrage, se connecter en **`NOVACORP\Administrateur`** avec le mot de passe de l'ancien administrateur local (pas le mot de passe DSRM), puis vérifier :

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, PDCEmulator
Resolve-DnsName _ldap._tcp.dc._msdcs.novacorp.test -Type SRV | Select-Object NameTarget
```



### 4. Déployer l'annuaire

```powershell
cd C:\TP\M1_Windows_AD_Scripts-main\scripts
Set-ExecutionPolicy -Scope Process Bypass
.\Deploy-NovaCorp.ps1 -WhatIf        # simulation : rien n'est modifié
.\Deploy-NovaCorp.ps1                # déploiement réel
.\Deploy-NovaCorp.ps1                # 2e passage : preuve d'idempotence
```

Le mot de passe initial des comptes est demandé une seule fois (saisie masquée). Il doit respecter la complexité du domaine ; les utilisateurs devront le changer à la première connexion.

Pour le fournir sans saisie interactive :

```powershell
.\Deploy-NovaCorp.ps1 -InitialPassword (Read-Host -AsSecureString "Mot de passe initial")
```

Résultats attendus avec le CSV fourni (24 utilisateurs, 5 services) :

| Passage | Bilan |
|---|---|
| `-WhatIf` | uniquement des lignes `[WhatIf] ... a creer`, 0 erreur |
| 1er passage | 46 créé(s) (7 OU, 15 groupes, 24 utilisateurs), 53 modifié(s), 0 erreur |
| 2e passage | **0 créé(s), 0 modifié(s)**, uniquement des objets inchangés |

### 5. Contrôler la conformité

```powershell
.\Test-NovaCorp.ps1
```

Attendu : **0 FAIL**. Avec un seul contrôleur de domaine, deux `[WARN]` sont normaux :

- `1 controleur(s) de domaine (minimum attendu : 2)` ;
- `Replication non testable : moins de deux controleurs`.

### 6. (Optionnel) Tester la correction de dérive

Provoquer une dérive, puis relancer le déploiement :

```powershell
Set-ADUser alice.martin -Department "IT"                                   # mauvais service
Move-ADObject (Get-ADUser hugo.bernard).DistinguishedName -TargetPath "OU=IT,OU=NovaCorp,DC=novacorp,DC=test"   # mauvaise OU
Add-ADGroupMember GG_IT -Members emma.robert                               # mauvais groupe

.\Deploy-NovaCorp.ps1      # signale et corrige les trois dérives (lignes [WARN] Derive)
.\Test-NovaCorp.ps1        # de nouveau 0 FAIL
```

---

## Ce que fait `Deploy-NovaCorp.ps1`

1. **OU** : `NovaCorp`, `NovaCorp\Groups` et une OU par service, protégées contre la suppression.
2. **Groupes** par service : `GG_<Service>` (global, dans l'OU du service), `DL_<Service>_RW` et `DL_<Service>_R` (domaine local, dans `Groups`). La description d'un groupe existant est réalignée.
3. **AGDLP** : `GG_<Service>` → `DL_<Service>_RW` ; `GG_Direction` → `DL_<autre service>_R` (lecture transverse de la Direction).
4. **Utilisateurs** : créés s'ils manquent ; s'ils existent, correction de `Department`, `Office` et de l'OU sans recréation. Un compte désactivé est signalé, pas réactivé.
5. **Appartenances** : chaque utilisateur est dans le `GG` de son service et retiré des `GG` des autres services du CSV. Les groupes hors CSV (ex. `GG_HELPDESK`) ne sont jamais touchés.
6. **Responsables** : attribut `Manager` renseigné depuis la colonne du même nom.

Une erreur sur un objet est journalisée et le script passe au suivant.

---

## Format du CSV

Séparateur `;`, encodage UTF-8, première ligne = en-têtes.

```
Firstname;Lastname;Department;Site;Manager
Claire;Durand;Direction;Paris;
Alice;Martin;Finance;Paris;claire.durand
```

| Colonne | Obligatoire | Utilisation |
|---|---|---|
| `Firstname` | oui | prénom (première partie du login) |
| `Lastname` | oui | nom (seconde partie du login) |
| `Department` | oui | service : OU, groupe `GG_<Service>`, attribut `Department` |
| `Site` | non | attribut `Office` |
| `Manager` | non | **login** du responsable (`prenom.nom`) |

Règles :

- Login = `prenom.nom`, en minuscules, sans accents (`Hélène` → `helene`), 20 caractères maximum.
- Garder une **orthographe unique** par service (`Finance` et `finance` seraient fusionnés).
- Les lignes sans prénom, nom ou service sont ignorées.
- Les **homonymes** ne sont pas gérés : deux « Jean Martin » donneraient le même login.

---

## Configuration

Tous les paramètres sont regroupés en tête de chaque script, dans le bloc `param()` sous le bandeau **CONFIGURATION**. Deux façons de les changer :

- modifier les valeurs par défaut dans le fichier ;
- les passer en ligne de commande pour un essai ponctuel :

```powershell
.\Deploy-NovaCorp.ps1 -RootOU Contoso -DepartmentsParentOU Users -CsvPath ..\datasets\users.csv -WhatIf
```

Principaux paramètres :

| Script | Paramètres |
|---|---|
| Install | `DomainName`, `NetbiosName`, `ForestMode`, `DomainMode`, `InstallDns`, `DatabasePath`, `AdLogPath`, `SysvolPath`, `RequireStaticIP` |
| Deploy | `CsvPath`, `CsvDelimiter`, `Col*` (noms des colonnes), `RootOU`, `GroupsOU`, `DepartmentsParentOU`, `GlobalGroupFormat`, `ModifyGroupFormat`, `ReadGroupFormat`, `ReadAllDepartment`, `SamFormat`, `SamMaxLength`, `UpnSuffix`, `EnableNewAccounts`, `ChangePasswordAtLogon` |
| Test | mêmes paramètres partagés que Deploy, plus `MinDomainControllers`, `DcPorts`, `ReplicationMaxAgeHours`, `AllowedPrivileged`, `BusinessGroupPattern` |

> Les valeurs marquées **`[PARTAGE]`** (CSV, OU, noms de groupes, format du login) existent dans `Deploy` **et** `Test` : les modifier dans les deux scripts, sinon le contrôle signalera des `[FAIL]` à tort.

---

## Journaux et codes de sortie

- `Install` et `Deploy` journalisent à l'écran et dans `scripts\logs\<install|deploy>-<date>.log`.
- `Test` affiche un résultat `[PASS]` / `[WARN]` / `[FAIL]` par contrôle et un bilan.

| Code | Install / Deploy | Test |
|---|---|---|
| 0 | aucune erreur | aucun `[FAIL]` |
| 1 | au moins une erreur | au moins un `[FAIL]` |
| 2 | prérequis manquant (module AD, CSV, droits…) | prérequis manquant |

Afficher les avertissements et le bilan du dernier déploiement :

```powershell
$log = Get-ChildItem .\logs\deploy-*.log | Sort-Object LastWriteTime | Select-Object -Last 1
Get-Content $log.FullName | Select-String 'WARN|ERROR|Bilan'
```

---

## Dépannage

| Symptôme | Cause / solution |
|---|---|
| Le script refuse de s'exécuter | `Set-ExecutionPolicy -Scope Process Bypass` et `Get-ChildItem -Recurse \| Unblock-File` |
| `CSV introuvable` | arborescence modifiée : passer `-CsvPath` |
| `Colonne(s) obligatoire(s) absente(s)` | mauvais séparateur ou en-têtes différents : ajuster `CsvDelimiter` / `Col*` |
| Accents corrompus dans les noms | CSV pas en UTF-8 |
| `[WARN] SRVTEST publie 2 adresses dans le DNS` | carte réseau supplémentaire ou ancienne adresse DHCP : désactiver la carte (ou `Set-DnsClient -RegisterThisConnectionsAddress $false`), ou supprimer l'enregistrement avec `Remove-DnsServerResourceRecord`, puis `ipconfig /registerdns` |
| `Get-ADDomain` : serveur introuvable juste après le redémarrage | attendre quelques minutes que les services AD démarrent |
| Téléchargement GitHub impossible après la promotion | le DNS du serveur est `127.0.0.1` : copier le ZIP depuis un autre poste |
| Lignes `WhatIf : ... Définir l'alias` | bruit du chargement d'un module en simulation, sans conséquence |

