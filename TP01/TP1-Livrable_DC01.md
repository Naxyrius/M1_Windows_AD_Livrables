# TP0 - Livrable

## Installation AD
Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools

Install-ADDSForest -DomainName novacorp.test -DomainNetBIOSName NOVACORP -InstallDNS:$true -SafeModeAdministratorPassword (ConvertTo-SecureString "Not24get" -AsPlainText -Force)

### Preuve
PS C:\WINDOWS\system32> Get-ADForest


ApplicationPartitions : {DC=DomainDnsZones,DC=novacorp,DC=test, DC=ForestDnsZones,DC=novacorp,DC=test}
CrossForestReferences : {}
DomainNamingMaster    : DC01.novacorp.test
Domains               : {novacorp.test}
ForestMode            : Windows2025Forest
GlobalCatalogs        : {DC01.novacorp.test}
Name                  : novacorp.test
PartitionsContainer   : CN=Partitions,CN=Configuration,DC=novacorp,DC=test
RootDomain            : novacorp.test
SchemaMaster          : DC01.novacorp.test
Sites                 : {Default-First-Site-Name}
SPNSuffixes           : {}
UPNSuffixes           : {}



PS C:\WINDOWS\system32> Get-ADDomain


AllowedDNSSuffixes                 : {}
ChildDomains                       : {}
ComputersContainer                 : CN=Computers,DC=novacorp,DC=test
DeletedObjectsContainer            : CN=Deleted Objects,DC=novacorp,DC=test
DistinguishedName                  : DC=novacorp,DC=test
DNSRoot                            : novacorp.test
DomainControllersContainer         : OU=Domain Controllers,DC=novacorp,DC=test
DomainMode                         : Windows2025Domain
DomainSID                          : S-1-5-21-1723281579-3114997196-3702512319
ForeignSecurityPrincipalsContainer : CN=ForeignSecurityPrincipals,DC=novacorp,DC=test
Forest                             : novacorp.test
InfrastructureMaster               : DC01.novacorp.test
LastLogonReplicationInterval       :
LinkedGroupPolicyObjects           : {CN={31B2F340-016D-11D2-945F-00C04FB984F9},CN=Policies,CN=System,DC=novac
                                     orp,DC=test}
LostAndFoundContainer              : CN=LostAndFound,DC=novacorp,DC=test
ManagedBy                          :
Name                               : novacorp
NetBIOSName                        : NOVACORP
ObjectClass                        : domainDNS
ObjectGUID                         : 52d83975-6e90-4dea-afb2-4ca93a9ad5c9
ParentDomain                       :
PDCEmulator                        : DC01.novacorp.test
PublicKeyRequiredPasswordRolling   : True
QuotasContainer                    : CN=NTDS Quotas,DC=novacorp,DC=test
ReadOnlyReplicaDirectoryServers    : {}
ReplicaDirectoryServers            : {DC01.novacorp.test}
RIDMaster                          : DC01.novacorp.test
SubordinateReferences              : {DC=ForestDnsZones,DC=novacorp,DC=test,
                                     DC=DomainDnsZones,DC=novacorp,DC=test,
                                     CN=Configuration,DC=novacorp,DC=test}
SystemsContainer                   : CN=System,DC=novacorp,DC=test
UsersContainer                     : CN=Users,DC=novacorp,DC=test



PS C:\WINDOWS\system32> Get-ADDomainController -Filter *


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
NTDSSettingsObjectDN       : CN=NTDS Settings,CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Config
                             uration,DC=novacorp,DC=test
OperatingSystem            : Windows Server 2025 Standard
OperatingSystemHotfix      :
OperatingSystemServicePack :
OperatingSystemVersion     : 10.0 (26100)
OperationMasterRoles       : {SchemaMaster, DomainNamingMaster, PDCEmulator, RIDMaster...}
Partitions                 : {DC=ForestDnsZones,DC=novacorp,DC=test, DC=DomainDnsZones,DC=novacorp,DC=test,
                             CN=Schema,CN=Configuration,DC=novacorp,DC=test,
                             CN=Configuration,DC=novacorp,DC=test...}
ServerObjectDN             : CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=novaco
                             rp,DC=test
ServerObjectGuid           : 0cfdf8e4-6806-407c-a28b-f019d75f6d5f
Site                       : Default-First-Site-Name
SslPort                    : 636



PS C:\WINDOWS\system32> Get-ADRootDSE


configurationNamingContext    : CN=Configuration,DC=novacorp,DC=test
currentTime                   : 01/10/2026 12:43:04
defaultNamingContext          : DC=novacorp,DC=test
dnsHostName                   : DC01.novacorp.test
domainControllerFunctionality : Windows2025
domainFunctionality           : Windows2025Domain
dsServiceName                 : CN=NTDS Settings,CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Con
                                figuration,DC=novacorp,DC=test
forestFunctionality           : Windows2025Forest
highestCommittedUSN           : 12782
isGlobalCatalogReady          : {TRUE}
isSynchronized                : {TRUE}
ldapServiceName               : novacorp.test:dc01$@NOVACORP.TEST
namingContexts                : {DC=novacorp,DC=test, CN=Configuration,DC=novacorp,DC=test,
                                CN=Schema,CN=Configuration,DC=novacorp,DC=test,
                                DC=DomainDnsZones,DC=novacorp,DC=test...}
rootDomainNamingContext       : DC=novacorp,DC=test
schemaNamingContext           : CN=Schema,CN=Configuration,DC=novacorp,DC=test
serverName                    : CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=nov
                                acorp,DC=test
subschemaSubentry             : CN=Aggregate,CN=Schema,CN=Configuration,DC=novacorp,DC=test
supportedCapabilities         : {1.2.840.113556.1.4.800 (LDAP_CAP_ACTIVE_DIRECTORY_OID),
                                1.2.840.113556.1.4.1670 (LDAP_CAP_ACTIVE_DIRECTORY_V51_OID),
                                1.2.840.113556.1.4.1791 (LDAP_CAP_ACTIVE_DIRECTORY_LDAP_INTEG_OID),
                                1.2.840.113556.1.4.1935 (LDAP_CAP_ACTIVE_DIRECTORY_V61_OID)...}
supportedControl              : {1.2.840.113556.1.4.319 (LDAP_PAGED_RESULT_OID_STRING),
                                1.2.840.113556.1.4.801 (LDAP_SERVER_SD_FLAGS_OID), 1.2.840.113556.1.4.473
                                (LDAP_SERVER_SORT_OID), 1.2.840.113556.1.4.528
                                (LDAP_SERVER_NOTIFICATION_OID)...}
supportedLDAPPolicies         : {MaxPoolThreads, MaxPercentDirSyncRequests, MaxDatagramRecv,
                                MaxReceiveBuffer...}
supportedLDAPVersion          : {3, 2}
supportedSASLMechanisms       : {GSSAPI, GSS-SPNEGO, EXTERNAL, DIGEST-MD5}



PS C:\WINDOWS\system32> netdom query fsmo
Contrôleur de schéma        DC01.novacorp.test
Maître des noms de domaine  DC01.novacorp.test
Contrôleur domaine princip. DC01.novacorp.test
Gestionnaire du pool RID    DC01.novacorp.test
Maître d’infrastructure     DC01.novacorp.test
L’opération s’est bien déroulée.

PS C:\WINDOWS\system32> dcdiag /test:dns

Diagnostic du serveur d'annuaire

Exécution de l'installation initiale :
   Tentative de recherche de serveur associé...
   Serveur associé : DC01
   * Forêt AD identifiée.
   Collecte des informations initiales terminée.

Exécution des tests initiaux nécessaires

   Test du serveur : Default-First-Site-Name\DC01
      Démarrage du test : Connectivity
         ......................... Le test Connectivity
          de DC01 a réussi

Exécution des tests principaux

   Test du serveur : Default-First-Site-Name\DC01

      Démarrage du test : DNS

         Les tests DNS sont en cours d'exécution et ne sont pas arrêtés. Veuillez patienter quelques
         minutes...
         ......................... Le test DNS
          de DC01 a réussi

   Exécution de tests de partitions sur ForestDnsZones

   Exécution de tests de partitions sur DomainDnsZones

   Exécution de tests de partitions sur Schema

   Exécution de tests de partitions sur Configuration

   Exécution de tests de partitions sur novacorp

   Exécution de tests d'entreprise sur novacorp.test
      Démarrage du test : DNS
         ......................... Le test DNS
          de novacorp.test a réussi
PS C:\WINDOWS\system32> Resolve-DnsName _ldap._tcp.dc._msdcs.novacorp.test -Type SRV

Name                                     Type   TTL   Section    NameTarget                     Priority Weigh
                                                                                                         t
----                                     ----   ---   -------    ----------                     -------- -----
_ldap._tcp.dc._msdcs.novacorp.test       SRV    600   Answer     dc01.novacorp.test             0        100

Name       : dc01.novacorp.test
QueryType  : A
TTL        : 3600
Section    : Additional
IP4Address : 10.100.12.11


Name       : dc01.novacorp.test
QueryType  : A
TTL        : 3600
Section    : Additional
IP4Address : 192.168.119.2

## Création de l'arborescence d'OU
PS C:\Users\Administrateur> C:\Users\Administrateur\Desktop\Initialize-NovaCorpOU.ps1
Création de l'OU NovaCorp...
Création de l'OU RH...
Création de l'OU IT...
Création de l'OU Finance...

PS C:\Users\Administrateur> C:\Users\Administrateur\Desktop\Initialize-NovaCorpOU.ps1
L'OU NovaCorp existe déjà, aucune création.
L'OU RH existe déjà, aucune création.
L'OU IT existe déjà, aucune création.
L'OU Finance existe déjà, aucune création.

PS C:\Users\Administrateur> C:\Users\Administrateur\Desktop\Initialize-NovaCorpOU.ps1
L'OU NovaCorp existe déjà, aucune création.
L'OU RH existe déjà, aucune création.
L'OU IT existe déjà, aucune création.
L'OU Finance existe déjà, aucune création.


## Validation d'apaprtenance SRV01

```
(Get-CimInstance Win32_ComputerSystem) | Select Name, Domain, PartOfDomain

Name  Domain        PartOfDomain
----  ------        ------------
SRV01 novacorp.test         True
```

Le srv01 a bien rejoint le domaine