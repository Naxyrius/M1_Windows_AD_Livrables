# Rapport d'incident — Résolution de panne d'infrastructure sur CLT01

- **Poste client :** `CLT01` (`10.100.12.13`)
- **Contrôleurs cibles :** `DC01` (`10.100.12.11`), `DC02` (`10.100.12.12`)
- **Périmètre d'impact :** Perte de liaison physique, désynchronisation horaire et rupture du canal sécurisé (*secure channel*)

---

## 1. Symptômes initiaux et premier secours

1. **Arrêt d'urgence programmé :**  
   Une planification d'extinction forcée de 5 minutes a été neutralisée en console administrative :
   ```cmd
   shutdown /a
   ```
2. **Disparition de la connectivité réseau :**  
   L'interface de production présentait une absence de lien puis une adresse d'autoconfiguration APIPA (`169.254.149.149/16`), isolant complètement la machine du domaine `novacorp.test`.

---

## 2. Rétablissement de la couche réseau (L1 / L2 / L3)

### Adressage IP de CLT01
Après réactivation du périphérique virtuel et réassignation de l'adresse statique sur `Ethernet1` :

```powershell
ipconfig
```

```text
Configuration IP de Windows


Carte Ethernet Ethernet0 :

   Suffixe DNS propre à la connexion. . . : localdomain
   Adresse IPv6 de liaison locale. . . . .: fe80::6492:488d:7fef:103b%20
   Adresse IPv4. . . . . . . . . . . . . .: 192.168.38.130
   Masque de sous-réseau. . . . . . . . . : 255.255.255.0
   Passerelle par défaut. . . . . . . . . : 192.168.38.254

Carte Ethernet Ethernet1 :

   Suffixe DNS propre à la connexion. . . :
   Adresse IPv6 de liaison locale. . . . .: fe80::fe07:3863:a1fc:b673%24
   Adresse IPv4. . . . . . . . . . . . . .: 10.100.12.13
   Masque de sous-réseau. . . . . . . . . : 255.255.255.0
   Passerelle par défaut. . . . . . . . . : 10.100.12.254
```

### Validation de la joignabilité IP (ICMP)

```powershell
ping 10.100.12.12
```

```text
Envoi d’une requête 'Ping'  10.100.12.12 avec 32 octets de données :
Réponse de 10.100.12.12 : octets=32 temps=6 ms TTL=128
Réponse de 10.100.12.12 : octets=32 temps=4 ms TTL=128
Réponse de 10.100.12.12 : octets=32 temps=2 ms TTL=128
Réponse de 10.100.12.12 : octets=32 temps=1 ms TTL=128

Statistiques Ping pour 10.100.12.12:
    Paquets : envoyés = 4, reçus = 4, perdus = 0 (perte 0%),
Durée approximative des boucles en millisecondes :
    Minimum = 1ms, Maximum = 6ms, Moyenne = 3ms
```

```powershell
ping 10.100.12.11
```

```text
Envoi d’une requête 'Ping'  10.100.12.11 avec 32 octets de données :
Réponse de 10.100.12.11 : octets=32 temps=1 ms TTL=128
Réponse de 10.100.12.11 : octets=32 temps=4 ms TTL=128
Réponse de 10.100.12.11 : octets=32 temps=3 ms TTL=128
Réponse de 10.100.12.11 : octets=32 temps=1 ms TTL=128

Statistiques Ping pour 10.100.12.11:
    Paquets : envoyés = 4, reçus = 4, perdus = 0 (perte 0%),
Durée approximative des boucles en millisecondes :
    Minimum = 1ms, Maximum = 4ms, Moyenne = 2ms
```

```powershell
ping 1.1.1.1
```

```text
Envoi d’une requête 'Ping'  1.1.1.1 avec 32 octets de données :
Réponse de 1.1.1.1 : octets=32 temps=6 ms TTL=128
Réponse de 1.1.1.1 : octets=32 temps=11 ms TTL=128
Réponse de 1.1.1.1 : octets=32 temps=8 ms TTL=128

Statistiques Ping pour 1.1.1.1:
    Paquets : envoyés = 3, reçus = 3, perdus = 0 (perte 0%),
Durée approximative des boucles en millisecondes :
    Minimum = 6ms, Maximum = 11ms, Moyenne = 8ms
```

---

## 3. Diagnostic des couches supérieures (DNS, LDAP, Kerberos)

### Échec de l'application des GPO

```powershell
gpupdate /force
```

```text
Mise à jour de la stratégie...

La stratégie de l'ordinateur n'a pas pu être mise à jour correctement. Les erreurs suivantes ont été rencontrées :

Échec du traitement de la stratégie de groupe en raison d'une absence de connectivité réseau vers un contrôleur de domaine. Il peut s'agir d'un problème temporaire. Un message de réussite est généré une fois que l'ordinateur est connecté au contrôleur de domaine et que la stratégie de groupe est correctement traitée. Si aucun message de réussite ne s'affiche pendant plusieurs heures, contactez votre administrateur.
La stratégie utilisateur n'a pas pu être mise à jour correctement. Les erreurs suivantes ont été rencontrées :

Échec du traitement de la stratégie de groupe. Windows n'a pas pu s'authentifier auprès du service Active Directory d'un contrôleur de domaine. (Échec de l'appel de fonction de liaison LDAP). Consultez l'onglet des détails pour plus d'informations sur le code d'erreur et la description.

Pour diagnostiquer la panne, ouvrez le journal des événements ou exécutez GPRESULT /H GPReport.html depuis la ligne de commande pour accéder aux résultats de la stratégie de groupe.
```

### Vérification de la résolution DNS

```powershell
Resolve-DnsName novacorp.test
```

```text
Name                                           Type   TTL   Section    IPAddress
----                                           ----   ---   -------    ---------
novacorp.test                                  A      600   Answer     10.100.12.11
novacorp.test                                  A      600   Answer     10.100.12.12
novacorp.test                                  A      600   Answer     192.168.119.2
```

### Test du port LDAP (TCP 389)

```powershell
Test-NetConnection -ComputerName 10.100.12.11 -Port 389
```

```text
ComputerName     : 10.100.12.11
RemoteAddress    : 10.100.12.11
RemotePort       : 389
InterfaceAlias   : Ethernet1
SourceAddress    : 10.100.12.13
TcpTestSucceeded : True
```

---

## 4. Identification de la cause racine et remédiation

Bien que la connectivité TCP 389 soit fonctionnelle, deux anomalies bloquaient l'authentification :

1. **Décalage temporel (*Clock Skew*) supérieur à 5 minutes :**  
   L'horloge locale de `CLT01` affichait environ 13 minutes d'avance par rapport au contrôleur de domaine, interdisant toute émission ou validation de ticket Kerberos.
2. **Désynchronisation du canal sécurisé (*Secure Channel*) :**  
   La relation de confiance entre le compte machine `CLT01$` et le domaine nécessitait une renégociation du secret partagé.

### Constat d'écart horaire

```powershell
Get-Date
```

```text
vendredi 2 octobre 2026 16:11:24
```

```powershell
w32tm /resync /force
```

```text
Envoi de la commande de resynchronisation à l’ordinateur local
L’ordinateur ne s’est pas resynchronisé car aucune donnée de temps n’était disponible.
```

### Réparation du canal sécurisé Netlogon

```powershell
Test-ComputerSecureChannel -Repair
```

```text
True
```

### Recalage forcé de l'horloge sur le contrôleur de domaine

```cmd
net time \\10.100.12.11 /set /y
```

```text
L’heure en cours sur \\10.100.12.11 est 02/10/2026 15:58:30

La commande s’est terminée correctement.
```

---

## 5. Recette finale

Une fois le secret machine réinitialisé et l'horloge recalée dans la fenêtre de tolérance Kerberos, l'authentification et la lecture LDAP sont pleinement restaurées :

```powershell
gpupdate /force
```

```text
Mise à jour de la stratégie...

La mise à jour de la stratégie d'ordinateur s'est terminée sans erreur.
La mise à jour de la stratégie utilisateur s'est terminée sans erreur.
```