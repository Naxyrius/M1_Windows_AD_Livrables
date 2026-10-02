# TP3 - Livrable

## ipconfig /all
PS C:\Users\claire.durand> ipconfig /all
 
Configuration IP de Windows
 ```
   Nom de l’hôte . . . . . . . . . . : CLT01
   Suffixe DNS principal . . . . . . : novacorp.test
   Type de noeud. . . . . . . . . .  : Hybride
   Routage IP activé . . . . . . . . : Non
   Proxy WINS activé . . . . . . . . : Non
   Liste de recherche du suffixe DNS.: novacorp.test
                                       localdomain
```

Carte Ethernet Ethernet1 :
 ```
   Suffixe DNS propre à la connexion. . . :
   Description. . . . . . . . . . . . . . : Intel(R) 82574L Gigabit Network Connection
   Adresse physique . . . . . . . . . . . : 00-0C-29-CC-0D-82
   DHCP activé. . . . . . . . . . . . . . : Non
   Configuration automatique activée. . . : Oui
   Adresse IPv6 de liaison locale. . . . .: fe80::4fc4:a4a2:527a:2f38%13(préféré)
   Adresse IPv4. . . . . . . . . . . . . .: 10.100.12.13(préféré)
   Masque de sous-réseau. . . . . . . . . : 255.255.255.0
   Passerelle par défaut. . . . . . . . . : 10.100.12.254
   IAID DHCPv6 . . . . . . . . . . . : 100666409
   DUID de client DHCPv6. . . . . . . . : 00-01-00-01-32-4F-CE-F5-00-0C-29-CC-0D-82
   Serveurs DNS. . .  . . . . . . . . . . : 10.100.12.11
                                       10.100.12.12
   NetBIOS sur Tcpip. . . . . . . . . . . : Activé
   ```
```
Carte Ethernet Ethernet0 :
 
   Suffixe DNS propre à la connexion. . . : localdomain
   Description. . . . . . . . . . . . . . : Intel(R) 82574L Gigabit Network Connection #2
   Adresse physique . . . . . . . . . . . : 00-0C-29-CC-0D-78
   DHCP activé. . . . . . . . . . . . . . : Oui
   Configuration automatique activée. . . : Oui
   Adresse IPv6 de liaison locale. . . . .: fe80::2a69:eda4:891b:5a4b%5(préféré)
   Adresse IPv4. . . . . . . . . . . . . .: 192.168.38.130(préféré)
   Masque de sous-réseau. . . . . . . . . : 255.255.255.0
   Bail obtenu. . . . . . . . . . . . . . : jeudi 1 octobre 2026 12:54:08
   Bail expirant. . . . . . . . . . . . . : jeudi 1 octobre 2026 17:25:17
   Passerelle par défaut. . . . . . . . . : 192.168.38.254
   Serveur DHCP . . . . . . . . . . . . . : 192.168.38.254
   IAID DHCPv6 . . . . . . . . . . . : 167775273
   DUID de client DHCPv6. . . . . . . . : 00-01-00-01-32-4F-CE-F5-00-0C-29-CC-0D-82
   Serveurs DNS. . .  . . . . . . . . . . : 192.168.38.254
   Serveur WINS principal . . . . . . . . : 192.168.38.254
   NetBIOS sur Tcpip. . . . . . . . . . . : Activé
```
## Resolve-DNSname

PS C:\Users\claire.durand> Resolve-DnsName _ldap._tcp.dc._msdcs.novacorp.test -Type SRV

```
Name                                     Type   TTL   Section    NameTarget                     Priority Weight Port
----                                     ----   ---   -------    ----------                     -------- ------ ----
_ldap._tcp.dc._msdcs.novacorp.test       SRV    600   Answer     dc02.novacorp.test             0        100    389
_ldap._tcp.dc._msdcs.novacorp.test       SRV    600   Answer     dc01.novacorp.test             0        100    389
 
Name       : dc02.novacorp.test
QueryType  : A
TTL        : 3600
Section    : Additional
IP4Address : 10.100.12.12
 
 
Name       : dc02.novacorp.test
QueryType  : A
TTL        : 3600
Section    : Additional
IP4Address : 192.168.122.228
 
 
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
```

## nltest
```
C:\Users\claire.durand> nltest /dsgetdc:novacorp.test
           Contrôleur de domaine : \\DC01.novacorp.test
      Adresse : \\10.100.12.11
     GUID dom : 52d83975-6e90-4dea-afb2-4ca93a9ad5c9
     Nom dom : novacorp.test
  Nom de la forêt : novacorp.test
Nom de site du contrôleur de domaine : Default-First-Site-Name
Nom de notre site : Default-First-Site-Name
        Indicateurs : PDC GC DS LDAP KDC TIMESERV GTIMESERV WRITABLE DNS_DC DNS_DOMAIN DNS_FOREST CLOSE_SITE FULL_SECRET WS DS_8 DS_9 DS_10 KEYLIST 0x40000
La commande a été correctement exécutée
```

## Kerberos test sur CLT01

### List tickets

C:\Users\claire.durand>klist
 
LogonId est 0:0x12b14cd
 
Tickets mis en cache : (7)
``` 
#0>     Client : claire.durand @ NOVACORP.TEST
        Serveur : krbtgt/NOVACORP.TEST @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x60a10000 -> forwardable forwarded renewable pre_authent name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0x2 -> DELEGATION
        KDC appelé : DC02.novacorp.test
```
``` 
#1>     Client : claire.durand @ NOVACORP.TEST
        Serveur : krbtgt/NOVACORP.TEST @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40e10000 -> forwardable renewable initial pre_authent name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0x1 -> PRIMARY
        KDC appelé : DC02
```
``` 
#2>     Client : claire.durand @ NOVACORP.TEST
        Serveur : cifs/SRV01.novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a10000 -> forwardable renewable pre_authent name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```
``` 
#3>     Client : claire.durand @ NOVACORP.TEST
        Serveur : ldap/DC01.novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```
``` 
#4>     Client : claire.durand @ NOVACORP.TEST
        Serveur : cifs/DC01.novacorp.test/novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```
``` 
#5>     Client : claire.durand @ NOVACORP.TEST
        Serveur : ldap/DC01.novacorp.test/novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```
``` 
#6>     Client : claire.durand @ NOVACORP.TEST
        Serveur : LDAP/DC02.novacorp.test/novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
        Heure de démarrage : 10/1/2026 16:46:25 (Local)
        Heure de fin :   10/2/2026 2:46:25 (Local)
        Heure de renouvellement : 10/8/2026 16:46:25 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```

### Purge 
C:\Users\claire.durand>klist purge

``` 
LogonId est 0:0x12b14cd
        Suppression de tous les tickets :
        ticket(s) supprimé(s) !
```

### List tickets apres demande d'accès au partage Direction

C:\Users\claire.durand>klist
 
LogonId est 0:0x12b14cd
 
Tickets mis en cache : (2)
``` 
#0>     Client : claire.durand @ NOVACORP.TEST
        Serveur : krbtgt/NOVACORP.TEST @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40e10000 -> forwardable renewable initial pre_authent name_canonicalize
        Heure de démarrage : 10/1/2026 16:54:21 (Local)
        Heure de fin :   10/2/2026 2:54:21 (Local)
        Heure de renouvellement : 10/8/2026 16:54:21 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0x1 -> PRIMARY
        KDC appelé : DC02.novacorp.test
 
#1>     Client : claire.durand @ NOVACORP.TEST
        Serveur : ldap/DC01.novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
        Heure de démarrage : 10/1/2026 16:54:21 (Local)
        Heure de fin :   10/2/2026 2:54:21 (Local)
        Heure de renouvellement : 10/8/2026 16:54:21 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```

## Challenge SPN

```
PS C:\WINDOWS\system32> setspn -L sophie.mercier
Noms ServicePrincipalName inscrits pour CN=Sophie Mercier,OU=Direction,OU=NovaCorp,DC=novacorp,DC=test:
PS C:\WINDOWS\system32> setspn -X
Vérification du domaine DC=novacorp,DC=test
Traitement de l'entrée 0
0 groupe de SPN en double détectés.
```

## Expert - prouver l'utilisation de kerberos
```
Tickets mis en cache : (2)
 
#0>     Client : claire.durand @ NOVACORP.TEST
        Serveur : krbtgt/NOVACORP.TEST @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40e10000 -> forwardable renewable initial pre_authent name_canonicalize
        Heure de démarrage : 10/1/2026 16:54:21 (Local)
        Heure de fin :   10/2/2026 2:54:21 (Local)
        Heure de renouvellement : 10/8/2026 16:54:21 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0x1 -> PRIMARY
        KDC appelé : DC02.novacorp.test
 
#1>     Client : claire.durand @ NOVACORP.TEST
        Serveur : ldap/DC01.novacorp.test @ NOVACORP.TEST
        Type de chiffrement KerbTicket : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de tickets 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
        Heure de démarrage : 10/1/2026 16:54:21 (Local)
        Heure de fin :   10/2/2026 2:54:21 (Local)
        Heure de renouvellement : 10/8/2026 16:54:21 (Local)
        Type de clé de session : AES-256-CTS-HMAC-SHA1-96
        Indicateurs de cache : 0
        KDC appelé : DC02.novacorp.test
```
```
PS C:\WINDOWS\system32> Get-WinEvent -ComputerName SRV01 -LogName Security -FilterXPath "*[System[EventID=4624] and EventData[Data[@Name='AuthenticationPackageName']='Kerberos']]" -MaxEvents 10


   ProviderName : Microsoft-Windows-Security-Auditing

TimeCreated                      Id LevelDisplayName Message
-----------                      -- ---------------- -------
01/10/2026 16:31:37            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:31:37            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:15:40            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:15:40            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:08:46            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:08:46            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:08:46            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:04:22            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:01:02            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 15:25:54            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
```

## Via Event Viewer 

```
PS C:\WINDOWS\system32> Get-WinEvent -ComputerName SRV01 -LogName Security -FilterXPath "*[System[EventID=4624] and EventData[Data[@Name='AuthenticationPackageName']='NTLM']]" -MaxEvents 10


   ProviderName : Microsoft-Windows-Security-Auditing

TimeCreated                      Id LevelDisplayName Message
-----------                      -- ---------------- -------
01/10/2026 16:00:32            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 16:00:19            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 14:22:46            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 14:22:45            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 14:19:45            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 14:19:44            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 14:01:35            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 14:01:33            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 12:27:50            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...
01/10/2026 12:27:49            4624 Information      L'ouverture de session d'un compte s'est correctement dérou...


PS C:\WINDOWS\system32> Get-WinEvent -ComputerName SRV01 -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 20 | Select-Object TimeCreated,
>>     @{Name='Utilisateur';Expression={$_.Properties[5].Value}},
>>     @{Name='Protocole';Expression={$_.Properties[10].Value}},
>>     @{Name='IP Source';Expression={$_.Properties[18].Value}} | Format-Table -AutoSize

TimeCreated         Utilisateur   Protocole IP Source
-----------         -----------   --------- ---------
01/10/2026 16:31:37 SRV01$        Kerberos  ::1
01/10/2026 16:31:37 SRV01$        Kerberos  ::1
01/10/2026 16:30:09 Système       Negotiate -
01/10/2026 16:28:37 Système       Negotiate -
01/10/2026 16:28:32 Système       Negotiate -
01/10/2026 16:27:35 Système       Negotiate -
01/10/2026 16:26:48 Système       Negotiate -
01/10/2026 16:22:50 Système       Negotiate -
01/10/2026 16:22:49 Système       Negotiate -
01/10/2026 16:22:49 Système       Negotiate -
01/10/2026 16:22:00 Système       Negotiate -
01/10/2026 16:16:48 Système       Negotiate -
01/10/2026 16:15:40 SRV01$        Kerberos  ::1
01/10/2026 16:15:40 SRV01$        Kerberos  ::1
01/10/2026 16:15:28 Système       Negotiate -
01/10/2026 16:10:18 Système       Negotiate -
01/10/2026 16:08:46 claire.durand Kerberos  10.100.12.13
01/10/2026 16:08:46 claire.durand Kerberos  10.100.12.13
01/10/2026 16:08:46 claire.durand Kerberos  10.100.12.13
01/10/2026 16:07:07 Système       Negotiate -
```