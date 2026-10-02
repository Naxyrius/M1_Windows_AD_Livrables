
## Plan d'adressage du groupe (10.100.12.0/24)

| VM    | IP           | Rôle           |
| ----- | ------------ | -------------- |
| DC01  | 10.100.12.11 | AD DS / DNS    |
| DC02  | 10.100.12.12 | AD DS / DNS    |
| SRV01 | 10.100.12.14 | Serveur membre |

## Côté VMware Workstation

- Éditeur de réseau virtuel → **VMnet0** en **Pont (Bridged)** sur la carte RJ45 physique
- SRV01 a deux cartes :
    - **Ethernet0** → NAT (VMnet8), `192.168.88.128`, accès Internet et RDP depuis l'hôte
    - **Ethernet1** → Bridge (VMnet0), `10.100.12.14`, réseau du lab

## 1. Activation du Bureau à distance (RDP)

powershell

```powershell
# Activer le Bureau à distance
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0

# Garder l'authentification NLA
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1

# Ouvrir le pare-feu (identifiant indépendant de la langue)
Enable-NetFirewallRule -Group "@FirewallAPI.dll,-28752"

# Vérifications
Get-NetFirewallRule -Group "@FirewallAPI.dll,-28752" | Select DisplayName, Enabled, Profile
Get-NetTCPConnection -LocalPort 3389 -State Listen
```

## 2. Configuration réseau de la carte du lab (Ethernet1)

powershell

```powershell
# IP fixe
New-NetIPAddress -InterfaceAlias "Ethernet1" -IPAddress 10.100.12.14 -PrefixLength 24

# DNS : DC01 puis DC02
Set-DnsClientServerAddress -InterfaceAlias "Ethernet1" -ServerAddresses 10.100.12.11,10.100.12.12

# Profil privé + ping entrant autorisé (nom interne, valable sur Windows FR)
Set-NetConnectionProfile -InterfaceAlias "Ethernet1" -NetworkCategory Private
Enable-NetFirewallRule -Name "FPS-ICMP4-ERQ-In*"

# Heure
Set-TimeZone -Id "Romance Standard Time"
Get-Date
```

## 3. Cohabitation avec la carte NAT (Ethernet0)

powershell

```powershell
# La carte NAT ne s'enregistre pas dans le DNS AD
Set-DnsClient -InterfaceAlias "Ethernet0" -RegisterThisConnectionsAddress $false

# Priorité à la carte du lab
Set-NetIPInterface -InterfaceAlias "Ethernet1" -InterfaceMetric 5
Set-NetIPInterface -InterfaceAlias "Ethernet0" -InterfaceMetric 50
```

## 4. Vérifications

```powershell
Get-NetIPConfiguration
Get-DnsClientServerAddress -InterfaceAlias "Ethernet1" -AddressFamily IPv4
Get-NetFirewallRule -Name "FPS-ICMP4-ERQ-In*" | Select DisplayName, Enabled
Get-NetConnectionProfile | Select InterfaceAlias, NetworkCategory

# Tests vers les DC (
Test-NetConnection 10.100.12.11   # DC01 -> PingSucceeded : True
Test-NetConnection 10.100.12.12   # DC02
ping 10.100.12.11                 # 3 ms, TTL=128
```

Sortie NetIpconfig :
```powershell

PS C:\WINDOWS\system32> Test-NetConnection 10.100.12.12

  

ComputerName           : 10.100.12.12

RemoteAddress          : 10.100.12.12

InterfaceAlias         : Ethernet1

SourceAddress          : 10.100.12.14

PingSucceeded          : True

PingReplyDetails (RTT) : 1 ms

```

  

```powershell

PS C:\WINDOWS\system32> Test-NetConnection 10.100.12.11

  

ComputerName           : 10.100.12.11

RemoteAddress          : 10.100.12.11

InterfaceAlias         : Ethernet1

SourceAddress          : 10.100.12.14

PingSucceeded          : True

PingReplyDetails (RTT) : 12 ms

```





## Challenge

```
PS C:\WINDOWS\system32> hostname
SRV01
PS C:\WINDOWS\system32> Get-NetAdapter | Select Name, MacAddress, InterfaceDescription, Status

Name      MacAddress        InterfaceDescription                          Status
----      ----------        --------------------                          ------
Ethernet0 00-0C-29-37-E8-D9 Intel(R) 82574L Gigabit Network Connection    Up
Ethernet1 00-0C-29-37-E8-E3 Intel(R) 82574L Gigabit Network Connection #2 Up


PS C:\WINDOWS\system32> hostname
SRV01
PS C:\WINDOWS\system32> Get-NetAdapter -Physical | Select Name, InterfaceDescription, MacAddress, LinkSpeed, Status


Name                 : Ethernet0
InterfaceDescription : Intel(R) 82574L Gigabit Network Connection
MacAddress           : 00-0C-29-37-E8-D9
LinkSpeed            : 1 Gbps
Status               : Up

Name                 : Ethernet1
InterfaceDescription : Intel(R) 82574L Gigabit Network Connection #2
MacAddress           : 00-0C-29-37-E8-E3
LinkSpeed            : 1 Gbps
Status               : Up


```

```
>> }
| SRV01 | <PC hôte> | Ethernet0 | 00-0C-29-37-E8-D9 | 192.168.88.128 | <VMnet> | <port> |
| SRV01 | <PC hôte> | Ethernet1 | 00-0C-29-37-E8-E3 | 10.100.12.14 | <VMnet> | <port> |
```


