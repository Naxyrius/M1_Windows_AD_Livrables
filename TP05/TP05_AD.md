# TP05 — Deuxième DC, réplication et Sites AD

- **Domaine Active Directory :** `novacorp.test`
- **Contrôleur DC01 (Siège) :** `10.100.12.11`
- **Contrôleur DC02 (Agence) :** `10.100.12.12`
- **Serveur membre SRV01 :** `10.100.12.14`
- **Poste client CLT01 :** `10.100.12.13`

---

## 🟢 1. Promotion et état de DC02

### Vérification de l'intégration des contrôleurs de domaine

```powershell
Get-ADDomainController -Filter *
```

```text
ComputerObjectDN           : CN=DC02,OU=Domain Controllers,DC=novacorp,DC=test
DefaultPartition           : DC=novacorp,DC=test
Domain                     : novacorp.test
Enabled                    : True
Forest                     : novacorp.test
HostName                   : DC02.novacorp.test
InvocationId               : 41175c1e-8465-4bd4-a750-9dd0451fc27b
IPv4Address                : 192.168.122.228
IPv6Address                : 
IsGlobalCatalog            : True
IsReadOnly                 : False
LdapPort                   : 389
Name                       : DC02
NTDSSettingsObjectDN       : CN=NTDS Settings,CN=DC02,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=novacorp,DC=test
OperatingSystem            : Windows Server 2025 Standard Evaluation
OperatingSystemHotfix      : 
OperatingSystemServicePack : 
OperatingSystemVersion     : 10.0 (26100)
OperationMasterRoles       : {}
Partitions                 : {DC=ForestDnsZones,DC=novacorp,DC=test, DC=DomainDnsZones,DC=novacorp,DC=test, CN=Schema,CN=Configuration,DC=novacorp,DC=test, CN=Configuration,DC=novacorp,DC=test...}
ServerObjectDN             : CN=DC02,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=novacorp,DC=test
ServerObjectGuid           : 52354178-ef6b-4923-9209-7255ac14e16f
Site                       : Default-First-Site-Name
SslPort                    : 636

ComputerObjectDN           : CN=DC01,OU=Domain Controllers,DC=novacorp,DC=test
DefaultPartition           : DC=novacorp,DC=test
Domain                     : novacorp.test
Enabled                    : True
Forest                     : novacorp.test
HostName                   : DC01.novacorp.test
InvocationId               : cc5d151b-0c50-4513-bdd7-a3a83620dbb4
IPv4Address                : 10.100.12.11
IPv6Address                : 
IsGlobalCatalog            : True
IsReadOnly                 : False
LdapPort                   : 389
Name                       : DC01
NTDSSettingsObjectDN       : CN=NTDS Settings,CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=novacorp,DC=test
OperatingSystem            : Windows Server 2025 Standard
OperatingSystemHotfix      : 
OperatingSystemServicePack : 
OperatingSystemVersion     : 10.0 (26100)
OperationMasterRoles       : {SchemaMaster, DomainNamingMaster, PDCEmulator, RIDMaster...}
Partitions                 : {DC=ForestDnsZones,DC=novacorp,DC=test, DC=DomainDnsZones,DC=novacorp,DC=test, CN=Schema,CN=Configuration,DC=novacorp,DC=test, CN=Configuration,DC=novacorp,DC=test...}
ServerObjectDN             : CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=novacorp,DC=test
ServerObjectGuid           : 0cfdf8e4-6806-407c-a28b-f019d75f6d5f
Site                       : Default-First-Site-Name
SslPort                    : 636
```

### Vérification des contextes de réplication entrants

```powershell
repadmin /showrepl
```

```text
Repadmin : exécution de la commande /showrepl sur le contrôleur de domaine complet localhost
Default-First-Site-Name\DC02
Options DSA : IS_GC
Options de site : (none)
GUID de l'objet DSA : fecb57f2-4b8b-484e-b269-924a024bed0f
ID de l'invocation DSA : 41175c1e-8465-4bd4-a750-9dd0451fc27b

=== INSTANCES VOISINES ENTRANTES ==================================

DC=novacorp,DC=test
    Default-First-Site-Name\DC01 via RPC
        GUID de l'objet DSA : cc5d151b-0c50-4513-bdd7-a3a83620dbb4
        La dernière tentative, le 2026-10-02 12:35:32, a réussi.

CN=Configuration,DC=novacorp,DC=test
    Default-First-Site-Name\DC01 via RPC
        GUID de l'objet DSA : cc5d151b-0c50-4513-bdd7-a3a83620dbb4
        La dernière tentative, le 2026-10-02 12:22:19, a réussi.

CN=Schema,CN=Configuration,DC=novacorp,DC=test
    Default-First-Site-Name\DC01 via RPC
        GUID de l'objet DSA : cc5d151b-0c50-4513-bdd7-a3a83620dbb4
        La dernière tentative, le 2026-10-02 12:21:37, a réussi.

DC=DomainDnsZones,DC=novacorp,DC=test
    Default-First-Site-Name\DC01 via RPC
        GUID de l'objet DSA : cc5d151b-0c50-4513-bdd7-a3a83620dbb4
        La dernière tentative, le 2026-10-02 11:56:34, a réussi.

DC=ForestDnsZones,DC=novacorp,DC=test
    Default-First-Site-Name\DC01 via RPC
        GUID de l'objet DSA : cc5d151b-0c50-4513-bdd7-a3a83620dbb4
        La dernière tentative, le 2026-10-02 11:56:34, a réussi.
```

---

## 🟢 2. Topologie des Sites AD et Sous-réseaux

### Configuration des sites et affectation du sous-réseau

```powershell
# Renommage du site par défaut
Get-ADReplicationSite -Identity "Default-First-Site-Name" | Rename-ADObject -NewName "SITE-HQ"

# Création du site distant
New-ADReplicationSite -Name "SITE-BRANCH"

# Vérification des sites existants
Get-ADReplicationSite -Filter * | Select-Object Name
```

```text
Name
----
SITE-HQ
SITE-BRANCH
```

```powershell
# Déclaration du sous-réseau local et association au siège
New-ADReplicationSubnet -Name "10.100.12.0/24" -Site "SITE-HQ"

# Validation de l'appartenance de la machine locale au site
nltest /dsgetsite
```

```text
SITE-HQ
La commande a été correctement exécutée
```

```powershell
# Déplacement de DC02 dans le site de l'agence
Move-ADDirectoryServer -Identity "DC02" -Site "SITE-BRANCH"

# Contrôle du déplacement
(Get-ADDomainController -Identity "DC02").Site
```

```text
SITE-BRANCH
```

---

## 🟢 3. Test réel de la réplication

### Création d'un objet sur DC02 et synchronisation forcée

```powershell
# Création d'une Unité d'Organisation test sur DC02
New-ADOrganizationalUnit -Name "OU_ReplicationTest" -Path "DC=novacorp,DC=test"

# Déclenchement de la synchronisation de toutes les partitions
repadmin /syncall /AePdq
```

```text
Synchronisation de tous les contextes de nom détenus sur DC02.
Synchronisation de la partition : DC=ForestDnsZones,DC=novacorp,DC=test
Synchronisation totale effectuée sans erreur.

Synchronisation de la partition : DC=DomainDnsZones,DC=novacorp,DC=test
Synchronisation totale effectuée sans erreur.

Synchronisation de la partition : CN=Schema,CN=Configuration,DC=novacorp,DC=test
Synchronisation totale effectuée sans erreur.

Synchronisation de la partition : CN=Configuration,DC=novacorp,DC=test
Synchronisation totale effectuée sans erreur.

Synchronisation de la partition : DC=novacorp,DC=test
Synchronisation totale effectuée sans erreur.
```

### Vérification de la présence de l'objet sur DC01

```powershell
Get-ADOrganizationalUnit -Filter "Name -eq 'OU_ReplicationTest'" -Server DC01.novacorp.test
```

```text
City                     : 
Country                  : 
DistinguishedName        : OU=OU_ReplicationTest,DC=novacorp,DC=test
LinkedGroupPolicyObjects : {}
ManagedBy                : 
Name                     : OU_ReplicationTest
ObjectClass              : organizationalUnit
ObjectGUID               : b997489f-3c69-44ac-8434-1673d4f46568
PostalCode               : 
State                    : 
StreetAddress            : 
```

### Explication : Comment sait-on que la réplication est saine ?
1. **Convergence des métadonnées (USN) :** L'objet créé sur un contrôleur porte un numéro de séquence mis à jour (`usnChanged`) propagé au partenaire de réplication sans conflit.
2. **Absence d'objets en conflit de collision :** Aucun objet n'est généré sous forme de collision d'annuaire (préfixé par `CNF:`).
3. **Succès des appels RPC :** `repadmin /syncall` se termine avec `Synchronisation totale effectuée sans erreur` sur les 5 partitions (Domain, Configuration, Schema, ForestDnsZones, DomainDnsZones), et `repadmin /showrepl` indique un statut sans échec.

---

## 🟢 4. Validation client (HQ et Branch)

*Notre infrastructure de TP reposant sur un groupe de 4 VM (`DC01`, `DC02`, `SRV01`, `CLT01`), les tests ont été validés sur le poste client membre `CLT01` rattaché à `SITE-HQ`.*

### Application des stratégies de groupe et rattachement de site sur CLT01

```powershell
gpresult /r
```

```text
Outil de résultat du système d’exploitation Microsoft (R) Windows (R) v2.0
© Microsoft Corporation. Tous droits réservés.

Créé le 02/10/2026 à 14:22:47

Données RSOP pour NOVACORP\Administrateur sur CLT01 : mode journalisation
--------------------------------------------------------------------------

Configuration du système d’exploitation : Station de travail membre
Version du système d’exploitation...... : 10.0.19045
Nom du site............................ : SITE-HQ
Profil itinérant :               N/A
Profil local........................... : C:\Users\Administrateur
Connexion via une liaison lente ? : Non

Paramètre de l’ordinateur
--------------------------
    CN=CLT01,OU=Workstations,DC=novacorp,DC=test
    Heure de la dernière application de la stratégie de groupe : 02/10/2026 à 14:14:41
    Stratégie de groupe appliquée depuis :      DC01.novacorp.test
    Seuil de liaison lente dans la stratégie de groupe :   500 kbps
    Nom du domaine......................... : NOVACORP
    Type de domaine........................ : Windows 2008 ou supérieur

    Objets Stratégie de groupe appliqués
    -------------------------------------
        GPO-Workstations-Security
        GPO-LAPS
        Default Domain Policy

    Les objets stratégie de groupe n’ont pas été appliqués
    car ils ont été refusés
    -----------------------------------------------------------------------------------
        Stratégie de groupe locale
          Filtrage :  Non appliqué (vide)

    L’ordinateur fait partie des groupes de sécurité suivants
    ---------------------------------------------------------
        Administrateurs
        Tout le monde
        Utilisateurs
        RESEAU
        Utilisateurs authentifiés
        Cette organisation
        CLT01$
        Ordinateurs du domaine
        Identité déclarée par une autorité d’authentification
        Niveau obligatoire système

PARAMÈTRES UTILISATEURS
------------------------
    CN=Administrateur,CN=Users,DC=novacorp,DC=test
    Heure de la dernière application de la stratégie de groupe : 02/10/2026 à 14:14:42
    Stratégie de groupe appliquée depuis :      DC01.novacorp.test
    Seuil de liaison lente dans la stratégie de groupe :   500 kbps
    Nom du domaine :                        NOVACORP
    Type de domaine :                        Windows 2008 ou supérieur

    Objets Stratégie de groupe appliqués
    -------------------------------------
        N/A

    Les objets stratégie de groupe n’ont pas été appliqués
    car ils ont été refusés
    -----------------------------------------------------------------------------------
        Stratégie de groupe locale
          Filtrage :  Non appliqué (vide)

    L’utilisateur fait partie des groupes de sécurité suivants
    ----------------------------------------------------------
        Utilisateurs du domaine
        Tout le monde
        Utilisateurs
        Administrateurs
        INTERACTIF
        OUVERTURE DE SESSION DE CONSOLE
        Utilisateurs authentifiés
        Cette organisation
        LOCAL
        Admins du domaine
        Propriétaires créateurs de la stratégie de groupe
        Administrateurs du schéma
        Administrateurs de l’entreprise
        Identité déclarée par une autorité d’authentification
        Groupe de réplication dont le mot de passe RODC est refusé
        Niveau obligatoire élevé
```

### Vérification de l'accès aux ressources réseau de SRV01

```powershell
Test-NetConnection -ComputerName 10.100.12.14 -Port 445
```

```text
ComputerName     : 10.100.12.14
RemoteAddress    : 10.100.12.14
RemotePort       : 445
InterfaceAlias   : Ethernet
SourceAddress    : 10.100.12.12
TcpTestSucceeded : True
```

### Comportement théorique attendu pour un client CLT02 sur l'agence distante
Dans le cadre d'un client `CLT02` positionné sur le réseau d'agence :
1. `nltest /dsgetsite` retourne `SITE-BRANCH`.
2. `nltest /dsgetdc:novacorp.test` retourne `DC02.novacorp.test`, confirmant la localisation de l'authentification sans traverser le WAN.
3. Les GPO sont téléchargées depuis le partage SYSVOL local de `DC02`.
4. L'accès aux partages de `SRV01` est routé à travers le réseau inter-sites.


---

## 🟠 Challenge — Inventaire et transfert FSMO

### 1. Inventaire initial des rôles FSMO

```powershell
netdom query fsmo
```

```text
Contrôleur de schéma        DC01.novacorp.test
Maître des noms de domaine  DC01.novacorp.test
Contrôleur domaine princip. DC01.novacorp.test
Gestionnaire du pool RID    DC01.novacorp.test
Maître d’infrastructure     DC01.novacorp.test
L’opération s’est bien déroulée.
```

### 2. Transfert du rôle RIDMaster vers DC02

```powershell
Move-ADDirectoryServerOperationMasterRole -Identity "DC02" -OperationMasterRole RIDMaster -Confirm:$false
```

### 3. Validation de la nouvelle répartition après transfert

```powershell
netdom query fsmo
```

```text
Contrôleur de schéma        DC01.novacorp.test
Maître des noms de domaine  DC01.novacorp.test
Contrôleur domaine princip. DC01.novacorp.test
Gestionnaire du pool RID    DC02.novacorp.test
Maître d’infrastructure     DC01.novacorp.test
L’opération s’est bien déroulée.
```

---

## 🔴 Expert — Panne irrécupérable : Transfer vs Seize

### Différence opérationnelle

| Critère                  | Transfert (*Transfer*)                                                                  | Saisie unilatérale (*Seize*)                                                                    |
| :----------------------- | :-------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------- |
| **État du DC source**    | En ligne, sain et joignable sur le réseau                                               | Hors ligne, détruit ou irrécupérable                                                            |
| **Mécanisme**            | Négociation gracieuse : synchronisation préalable des données du rôle entre les deux DC | Prise de contrôle unilatérale : le DC récepteur modifie ses propres attributs d'annuaire locaux |
| **Risque de corruption** | Nul                                                                                     | Présent si l'ancien détenteur est redémarré ultérieurement                                      |
| **Usage type**           | Maintenance préventive, équilibrage de charge, décommissionnement propre                | Panne matérielle critique, sinistre (PRA/DRP)                                                   |

### Précautions impératives avant de remettre en ligne un ancien détenteur après un Seize

- **Ne jamais reconnecter l'ancien DC au réseau :** Il ignore qu'il a perdu son rôle. S'il redémarre sur le LAN, il tentera de répliquer des données obsolètes ou d'émettre des identifiants, entraînant un **USN Rollback** et une corruption irrémédiable de l'annuaire (notamment pour le _RID Master_).

- **Nettoyer les métadonnées (_Metadata Cleanup_) :** Sur le DC survivant, supprimer l'ancien serveur dans la console _Sites et services AD_ (ou via `ntdsutil`), purger son compte dans _Domain Controllers_ et supprimer ses enregistrements DNS résiduels (`_msdcs`).

- **Réinstaller complètement la machine :** Si le serveur physique ou la VM doit resservir, le disque doit impérativement être formaté de zéro pour réintégrer l'annuaire sous une identité vierge.