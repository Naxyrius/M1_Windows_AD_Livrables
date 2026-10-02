# TP00 — Preflight : Cartographie et Validation Réseau

- **Sous-réseau :** `10.100.12.0/24`
- **Passerelle :** `10.100.12.254`
- **Date :** 2026-10-01

---

## 1. Cartographie du Lab (Challenge)

| VM        | Rôle                  | Hôte physique | MAC                 | IP             | Interface VMware | Port Switch |
| :-------- | :-------------------- | :------------ | :------------------ | :------------- | :--------------- | :---------- |
| **DC01**  | Contrôleur principal  | PC Léo        | `00-0C-29-5C-A5-CA` | `10.100.12.11` | Bridged          | P16         |
| **DC02**  | Contrôleur secondaire | PC Julien     | `52-54-00-D1-C1-35` | `10.100.12.12` | Bridged          | P2          |
| **CLT01** | Client Windows        | PC Axel       | `00-0C-29-CC-0D-82` | `10.100.12.13` | Bridged          | P14         |
| **SRV01** | Serveur membre        | PC Yann       | `00-0C-29-37-E8-E3` | `10.100.12.14` | Bridged          | P1          |

---

## 2. Validation de la connectivité

### Commande exécutée

```powershell
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

$tests = @(11, 12, 14) | ForEach-Object {
    $target = "10.100.12.$_"
    [PSCustomObject]@{
        Cible = $target
        Ping  = (Test-Connection -ComputerName $target -Count 1 -Quiet)
    }
}

[PSCustomObject]@{
    Hostname   = $env:COMPUTERNAME
    DateHeure  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    MAC        = $adapter.MacAddress
    IP         = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).IPAddress
    Passerelle = (Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
    Tests      = ($tests | Out-String).Trim()
} | Format-List
```

### Résultat obtenu

```text
Hostname   : CLT01
DateHeure  : 2026-10-01 12:59:16
MAC        : 00-0C-29-CC-0D-82
IP         : 10.100.12.13
Passerelle : 10.100.12.254
Tests      : Cible        Ping
             -----        ----
             10.100.12.11 True
             10.100.12.12 True
             10.100.12.14 True
```

- **Statut :** Connectivité validée (100 % des hôtes joignables).
- **Snapshot réalisé :** `TP00-BASE`.

---

## 3. Question Expert 🔴

**Pourquoi deux VM en mode NAT sur deux PC distincts ne forment-elles pas un même LAN ?**

1. **Isolation L2 :** Chaque hyperviseur génère son propre commutateur virtuel privé ; aucun domaine de diffusion n'est partagé.
2. **Masquage d'adresses (SNAT) :** Le trafic émis par une VM sort avec l'adresse IP de son PC hôte, masquant l'IP interne de la machine virtuelle.
3. **Absence de routage entrant (DNAT) :** Sans redirection explicite de ports sur l'hôte, une VM sur un PC A ne peut pas initier de connexion directe vers l'IP privée d'une VM sur un PC B.

Le mode **Bridged** est donc obligatoire pour raccorder directement les interfaces virtuelles au commutateur physique et partager le même sous-réseau `10.100.12.0/24`.