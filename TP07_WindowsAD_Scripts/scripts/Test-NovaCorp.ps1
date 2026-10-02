
[CmdletBinding()]
param(
    # ===================================================================================== CONFIGURATION

    # ----- Fichier source [PARTAGE]
    [string]$CsvPath,                                  # vide = <dossier du script>\..\datasets\employees.csv
    [string]$CsvDelimiter = ';',
    [string]$CsvEncoding = 'UTF8',
    [string]$ColFirstname = 'Firstname',
    [string]$ColLastname = 'Lastname',
    [string]$ColDepartment = 'Department',

    # ----- Arborescence, sous la racine du domaine [PARTAGE]
    [string]$RootOU = 'NovaCorp',
    [string]$GroupsOU = 'Groups',
    [string]$DepartmentsParentOU = '',                 # OU intermediaire des services ; '' = directement sous RootOU
    [bool]$RequireProtectedOUs = $true,                # $false = ne pas signaler les OU non protegees

    # ----- Nommage des groupes, {0} = nom du service [PARTAGE]
    [string]$GlobalGroupFormat = 'GG_{0}',
    [string]$ModifyGroupFormat = 'DL_{0}_RW',
    [string]$ReadGroupFormat = 'DL_{0}_R',
    [string]$ReadAllDepartment = 'Direction',          # '' = pas de lecture transverse a controler

    # ----- Comptes, {0} = prenom, {1} = nom [PARTAGE]
    [string]$SamFormat = '{0}.{1}',
    [int]$SamMaxLength = 20,
    [string]$SamInvalidChars = '[^a-z0-9.\-]',

    # ----- Controleurs de domaine
    [int]$MinDomainControllers = 2,                    # en dessous : avertissement (pas de redondance)
    [int[]]$DcPorts = @(389, 53),                      # ports testes sur chaque DC ; le premier sert aussi pour les detenteurs FSMO
    [int]$TcpTimeoutMs = 2000,
    [int]$ReplicationMaxAgeHours = 24,

    # ----- Groupes privilegies
    [string[]]$AllowedPrivileged = @(),                # SamAccountName acceptes en plus du compte Administrateur integre
    [string]$BusinessGroupPattern = '^(GG|DL)_'        # groupes metier interdits dans les groupes privilegies ; '' = pas de controle

    # =================================================================================================
)

# ----------------------------------------------------------------------------- chemins par defaut
# $PSScriptRoot peut etre vide dans param() (Windows PowerShell 5.1, ISE) : chemin calcule ici
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }
if (-not $CsvPath) { $CsvPath = Join-Path $scriptDir '..\datasets\employees.csv' }

$script:Count = @{ PASS = 0; WARN = 0; FAIL = 0 }

function Write-Check {
    param([ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status, [string]$Message)
    $script:Count[$Status]++
    $colors = @{ PASS = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }
    Write-Host ('[{0}] {1}' -f $Status, $Message) -ForegroundColor $colors[$Status]
}

function Remove-Diacritics {
    # Translitteration explicite (codes Unicode : le fichier reste en ASCII pur, sans dependre de l'encodage du script ni d'ICU)
    param([string]$Text)
    $pairs = 'E0:a,E1:a,E2:a,E3:a,E4:a,E5:a,E7:c,E8:e,E9:e,EA:e,EB:e,EC:i,ED:i,EE:i,EF:i,F1:n,F2:o,F3:o,F4:o,F5:o,F6:o,F9:u,FA:u,FB:u,FC:u,FD:y,FF:y,153:oe,E6:ae,DF:ss'
    $map = @{}
    foreach ($p in $pairs.Split(',')) {
        $kv = $p.Split(':')
        $map[[string][char][Convert]::ToInt32($kv[0], 16)] = $kv[1]
    }
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $Text.ToCharArray()) {
        $lower = [string]([char]::ToLowerInvariant($c))
        if ($map.ContainsKey($lower)) {
            $r = $map[$lower]
            if ([char]::IsUpper($c)) { $r = $r.Substring(0, 1).ToUpper() + $r.Substring(1) }
            [void]$sb.Append($r)
        }
        else { [void]$sb.Append($c) }
    }
    $out = $sb.ToString()
    try {
        # autres signes diacritiques eventuels : decomposition Unicode quand elle est disponible
        $n = $out.Normalize([System.Text.NormalizationForm]::FormD)
        $sb2 = New-Object System.Text.StringBuilder
        foreach ($c in $n.ToCharArray()) {
            if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb2.Append($c) }
        }
        $out = $sb2.ToString()
    }
    catch { }
    return $out
}

function New-SamAccountName {
    param([string]$First, [string]$Last)
    $s = (Remove-Diacritics ($SamFormat -f $First, $Last).Trim()).ToLower() -replace $SamInvalidChars, ''
    if ($s.Length -gt $SamMaxLength) { $s = $s.Substring(0, $SamMaxLength) }
    return $s.TrimEnd(".", "-")   # AD refuse un sAMAccountName termine par un point
}

function Get-Field {
    param($Row, [string]$Column)
    if (-not $Column) { return '' }
    $v = $Row.$Column
    if ($v) { return ([string]$v).Trim() }
    return ''
}

function Get-ParentDN {
    param([string]$DistinguishedName)
    return ($DistinguishedName -split '(?<!\\),', 2)[1]
}

function Get-ShortName {
    # dc02.novacorp.test -> DC02 ; CN=NTDS Settings,CN=DC02,... -> DC02
    param([string]$Value)
    if (-not $Value) { return '?' }
    if ($Value -match 'CN=NTDS Settings,CN=([^,]+)') { return $Matches[1].ToUpper() }
    return ($Value -split '\.')[0].ToUpper()
}

function Test-TcpPort {
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = $TcpTimeoutMs)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $client.EndConnect($iar)
        return $true
    }
    catch { return $false }
    finally { $client.Close() }
}

$groupCache = @{}
function Get-GroupCached {
    param([string]$Name)
    if (-not $groupCache.ContainsKey($Name)) {
        $groupCache[$Name] = Get-ADGroup -Filter "Name -eq '$Name'" -Properties Member -ErrorAction Stop
    }
    return $groupCache[$Name]
}

# ============================================================================= prerequis
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
    $forest = Get-ADForest -ErrorAction Stop
}
catch {
    Write-Host "[FAIL] Module ActiveDirectory ou domaine indisponible : $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Host "[FAIL] CSV introuvable : $CsvPath" -ForegroundColor Red
    exit 2
}
try {
    $raw = @(Import-Csv -LiteralPath $CsvPath -Delimiter $CsvDelimiter -Encoding $CsvEncoding -ErrorAction Stop)
}
catch {
    Write-Host "[FAIL] Lecture du CSV impossible : $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
if ($raw.Count -eq 0) {
    Write-Host "[FAIL] CSV vide : $CsvPath" -ForegroundColor Red
    exit 2
}
$headers = @($raw[0].PSObject.Properties | ForEach-Object { $_.Name })
$missing = @(@($ColFirstname, $ColLastname, $ColDepartment) | Where-Object { $headers -notcontains $_ })
if ($missing.Count -gt 0) {
    Write-Host "[FAIL] Colonne(s) absente(s) du CSV : $($missing -join ', ') (colonnes trouvees : $($headers -join ', '))" -ForegroundColor Red
    exit 2
}
$rows = @($raw | Where-Object { (Get-Field $_ $ColFirstname) -and (Get-Field $_ $ColLastname) -and (Get-Field $_ $ColDepartment) })
$departments = @($rows | ForEach-Object { Get-Field $_ $ColDepartment } | Sort-Object -Unique)
$domainDN = $domain.DistinguishedName
$dnsRoot = $domain.DNSRoot
$rootDN = "OU=$RootOU,$domainDN"
$deptParentDN = if ($DepartmentsParentOU) { "OU=$DepartmentsParentOU,$rootDN" } else { $rootDN }

Write-Host "Controle de $dnsRoot - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan

# ============================================================================= 1. OU
Write-Host '--- Structure des OU' -ForegroundColor Cyan
$expectedOUs = @($rootDN, "OU=$GroupsOU,$rootDN")
if ($DepartmentsParentOU) { $expectedOUs += $deptParentDN }
$expectedOUs += @($departments | ForEach-Object { "OU=$_,$deptParentDN" })
foreach ($dn in $expectedOUs) {
    try {
        $ou = Get-ADOrganizationalUnit -Identity $dn -Properties ProtectedFromAccidentalDeletion -ErrorAction Stop
        if ($ou.ProtectedFromAccidentalDeletion) { Write-Check PASS "OU presente et protegee : $dn" }
        elseif (-not $RequireProtectedOUs) { Write-Check PASS "OU presente : $dn" }
        else { Write-Check WARN "OU presente mais non protegee contre la suppression : $dn" }
    }
    catch { Write-Check FAIL "OU absente : $dn" }
}

# ============================================================================= 2. groupes
Write-Host '--- Groupes' -ForegroundColor Cyan
foreach ($d in $departments) {
    $specs = @(
        @{ N = ($GlobalGroupFormat -f $d); S = 'Global' },
        @{ N = ($ModifyGroupFormat -f $d); S = 'DomainLocal' },
        @{ N = ($ReadGroupFormat -f $d); S = 'DomainLocal' }
    )
    foreach ($spec in $specs) {
        try {
            $g = Get-GroupCached $spec.N
            if (-not $g) { Write-Check FAIL "Groupe absent : $($spec.N)" }
            elseif ([string]$g.GroupScope -ne $spec.S) { Write-Check FAIL "Groupe $($spec.N) de portee $($g.GroupScope) (attendu : $($spec.S))" }
            else { Write-Check PASS "Groupe $($spec.N) ($($spec.S))" }
        }
        catch { Write-Check FAIL "Groupe $($spec.N) : $($_.Exception.Message)" }
    }
}

# ============================================================================= 3. utilisateurs
Write-Host '--- Utilisateurs' -ForegroundColor Cyan
$userDN = @{}
$expectedSams = @{}
foreach ($row in $rows) {
    $dept = Get-Field $row $ColDepartment
    $sam = New-SamAccountName -First (Get-Field $row $ColFirstname) -Last (Get-Field $row $ColLastname)
    $expectedSams[$sam] = $true
    try {
        $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties Department, Enabled -ErrorAction Stop
        if (-not $u) { Write-Check FAIL "Utilisateur absent : $sam"; continue }
        $userDN[$sam] = $u.DistinguishedName
        $problems = @()
        if (-not $u.Enabled) { $problems += 'compte desactive' }
        if ($u.Department -ne $dept) { $problems += "Department='$($u.Department)' (attendu '$dept')" }
        $expectedOU = "OU=$dept,$deptParentDN"
        if ((Get-ParentDN $u.DistinguishedName) -ne $expectedOU) { $problems += "dans '$(Get-ParentDN $u.DistinguishedName)' (attendu '$expectedOU')" }
        if ($problems.Count -eq 0) { Write-Check PASS "Utilisateur conforme : $sam ($dept)" }
        else { Write-Check FAIL "Utilisateur $sam : $($problems -join ' ; ')" }
    }
    catch { Write-Check FAIL "Utilisateur $sam : $($_.Exception.Message)" }
}
foreach ($d in $departments) {
    try {
        $extra = @(Get-ADUser -Filter * -SearchBase "OU=$d,$deptParentDN" -SearchScope Subtree -ErrorAction Stop |
                Where-Object { -not $expectedSams.ContainsKey($_.SamAccountName.ToLower()) })
        if ($extra.Count -gt 0) { Write-Check WARN "OU $d : compte(s) absent(s) du CSV : $(($extra | ForEach-Object { $_.SamAccountName }) -join ', ')" }
    }
    catch { }
}

# ============================================================================= 4. appartenances
Write-Host '--- Appartenances' -ForegroundColor Cyan
foreach ($row in $rows) {
    $dept = Get-Field $row $ColDepartment
    $sam = New-SamAccountName -First (Get-Field $row $ColFirstname) -Last (Get-Field $row $ColLastname)
    if (-not $userDN.ContainsKey($sam)) { continue }
    $ownName = $GlobalGroupFormat -f $dept
    try {
        $gg = Get-GroupCached $ownName
        $inOwn = $gg -and ($gg.Member -contains $userDN[$sam])
        $wrong = @($departments | Where-Object { $_ -ne $dept } | Where-Object {
                $o = Get-GroupCached ($GlobalGroupFormat -f $_); $o -and ($o.Member -contains $userDN[$sam]) })
        if ($inOwn -and $wrong.Count -eq 0) { Write-Check PASS "$sam est dans $ownName uniquement" }
        elseif (-not $inOwn) { Write-Check FAIL "$sam n'est pas membre de $ownName" }
        else { Write-Check FAIL "$sam est aussi dans : $(($wrong | ForEach-Object { $GlobalGroupFormat -f $_ }) -join ', ')" }
    }
    catch { Write-Check FAIL "Appartenances de $sam : $($_.Exception.Message)" }
}
foreach ($d in $departments) {
    $ggName = $GlobalGroupFormat -f $d; $rwName = $ModifyGroupFormat -f $d
    try {
        $gg = Get-GroupCached $ggName; $dl = Get-GroupCached $rwName
        if ($gg -and $dl -and ($dl.Member -contains $gg.DistinguishedName)) { Write-Check PASS "$ggName est membre de $rwName" }
        else { Write-Check FAIL "$ggName n'est pas membre de $rwName" }
    }
    catch { Write-Check FAIL "Imbrication $ggName : $($_.Exception.Message)" }
}
if ($ReadAllDepartment -and ($departments -contains $ReadAllDepartment)) {
    $readAllName = $GlobalGroupFormat -f $ReadAllDepartment
    foreach ($d in ($departments | Where-Object { $_ -ne $ReadAllDepartment })) {
        $rName = $ReadGroupFormat -f $d
        try {
            $gg = Get-GroupCached $readAllName; $dl = Get-GroupCached $rName
            if ($gg -and $dl -and ($dl.Member -contains $gg.DistinguishedName)) { Write-Check PASS "$readAllName est membre de $rName" }
            else { Write-Check FAIL "$readAllName n'est pas membre de $rName" }
        }
        catch { Write-Check FAIL "Lecture transverse sur $d : $($_.Exception.Message)" }
    }
}

# ============================================================================= 5. controleurs de domaine
Write-Host '--- Controleurs de domaine' -ForegroundColor Cyan
$dcs = @()
try { $dcs = @(Get-ADDomainController -Filter * -ErrorAction Stop) }
catch { Write-Check FAIL "Liste des controleurs impossible : $($_.Exception.Message)" }
if ($dcs.Count -gt 0 -and $dcs.Count -lt $MinDomainControllers) {
    Write-Check WARN "$($dcs.Count) controleur(s) de domaine (minimum attendu : $MinDomainControllers) : redondance insuffisante"
}

# DNS SRV
try {
    $srv = @(Resolve-DnsName "_ldap._tcp.dc._msdcs.$dnsRoot" -Type SRV -ErrorAction Stop | Where-Object { $_.Type -eq 'SRV' })
    $targets = @($srv | ForEach-Object { ([string]$_.NameTarget).TrimEnd('.').ToLower() })
    if ($targets.Count -eq 0) { Write-Check FAIL "Aucun enregistrement SRV _ldap._tcp.dc._msdcs.$dnsRoot" }
    foreach ($dc in $dcs) {
        if ($targets -contains $dc.HostName.ToLower()) { Write-Check PASS "SRV LDAP present pour $($dc.Name)" }
        else { Write-Check FAIL "SRV LDAP absent pour $($dc.Name) ($($dc.HostName))" }
    }
}
catch { Write-Check FAIL "Resolution SRV _ldap._tcp.dc._msdcs.$dnsRoot impossible : $($_.Exception.Message)" }
try {
    $krb = @(Resolve-DnsName "_kerberos._tcp.$dnsRoot" -Type SRV -ErrorAction Stop | Where-Object { $_.Type -eq 'SRV' })
    if ($krb.Count -gt 0) { Write-Check PASS "SRV Kerberos present ($($krb.Count) enregistrement(s))" }
    else { Write-Check FAIL "Aucun enregistrement SRV _kerberos._tcp.$dnsRoot" }
}
catch { Write-Check FAIL "Resolution SRV Kerberos impossible : $($_.Exception.Message)" }

# adresses des DC dans le DNS (un DC a plusieurs cartes publie plusieurs adresses)
foreach ($dc in $dcs) {
    try {
        $a = @(Resolve-DnsName $dc.HostName -Type A -ErrorAction Stop | Where-Object { $_.Type -eq 'A' })
        if ($a.Count -gt 1) { Write-Check WARN "$($dc.Name) publie $($a.Count) adresses dans le DNS : $(($a | ForEach-Object { $_.IPAddress }) -join ', ') (carte supplementaire ?)" }
        elseif ($a.Count -eq 1) { Write-Check PASS "$($dc.Name) publie une seule adresse : $($a[0].IPAddress)" }
    }
    catch { Write-Check FAIL "Resolution DNS de $($dc.HostName) impossible" }
}

# joignabilite
foreach ($dc in $dcs) {
    $open = @($DcPorts | Where-Object { Test-TcpPort -ComputerName $dc.HostName -Port $_ })
    $closed = @($DcPorts | Where-Object { $open -notcontains $_ })
    if ($closed.Count -eq 0) { Write-Check PASS "$($dc.Name) joignable (ports $($DcPorts -join ', '))" }
    elseif ($open.Count -gt 0) { Write-Check WARN "$($dc.Name) partiellement joignable (ouverts : $($open -join ', ') ; fermes : $($closed -join ', '))" }
    else { Write-Check FAIL "$($dc.Name) injoignable (ports $($DcPorts -join ', ') fermes)" }
}

# ============================================================================= 6. replication
Write-Host '--- Replication' -ForegroundColor Cyan
if ($dcs.Count -lt 2) {
    Write-Check WARN 'Replication non testable : moins de deux controleurs'
}
foreach ($dc in $dcs) {
    try {
        $failures = @(Get-ADReplicationFailure -Target $dc.HostName -Scope Server -ErrorAction Stop | Where-Object { $_.FailureCount -gt 0 })
        if ($failures.Count -eq 0) { Write-Check PASS "Replication entrante sans echec sur $($dc.Name)" }
        foreach ($f in $failures) {
            Write-Check FAIL "Replication $(Get-ShortName $f.Partner) -> $($dc.Name) (echecs : $($f.FailureCount), derniere erreur : $($f.LastError))"
        }
    }
    catch { Write-Check FAIL "Etat de replication de $($dc.Name) illisible : $($_.Exception.Message)" }
    try {
        $limit = (Get-Date).AddHours(-$ReplicationMaxAgeHours)
        foreach ($p in @(Get-ADReplicationPartnerMetadata -Target $dc.HostName -Scope Server -ErrorAction Stop)) {
            if ($p.LastReplicationSuccess -and $p.LastReplicationSuccess -lt $limit) {
                Write-Check WARN "Derniere replication reussie $(Get-ShortName $p.Partner) -> $($dc.Name) : $($p.LastReplicationSuccess) (plus de $ReplicationMaxAgeHours h)"
            }
        }
    }
    catch { }
}

# ============================================================================= 7. FSMO
Write-Host '--- Roles FSMO' -ForegroundColor Cyan
$fsmoPort = $DcPorts[0]
$roles = @(
    @{ Role = 'SchemaMaster'; Holder = $forest.SchemaMaster },
    @{ Role = 'DomainNamingMaster'; Holder = $forest.DomainNamingMaster },
    @{ Role = 'PDCEmulator'; Holder = $domain.PDCEmulator },
    @{ Role = 'RIDMaster'; Holder = $domain.RIDMaster },
    @{ Role = 'InfrastructureMaster'; Holder = $domain.InfrastructureMaster }
)
foreach ($r in $roles) {
    $holder = ([string]$r.Holder).ToLower()
    if (-not $holder) { Write-Check FAIL "FSMO $($r.Role) : aucun detenteur"; continue }
    $known = @($dcs | Where-Object { $_.HostName.ToLower() -eq $holder }).Count -gt 0
    if ($dcs.Count -gt 0 -and -not $known) { Write-Check FAIL "FSMO $($r.Role) : detenteur $holder absent de la liste des controleurs" }
    elseif (Test-TcpPort -ComputerName $holder -Port $fsmoPort) { Write-Check PASS "FSMO $($r.Role) = $(Get-ShortName $holder)" }
    else { Write-Check FAIL "FSMO $($r.Role) : detenteur $(Get-ShortName $holder) injoignable (port $fsmoPort)" }
}

# ============================================================================= 8. groupes privilegies
Write-Host '--- Groupes privilegies' -ForegroundColor Cyan
$domSid = $domain.DomainSID.Value
$privGroups = @(
    @{ Name = 'Domain Admins'; Id = "$domSid-512" },
    @{ Name = 'Enterprise Admins'; Id = "$domSid-519" },
    @{ Name = 'Schema Admins'; Id = "$domSid-518" },
    @{ Name = 'Administrators'; Id = 'S-1-5-32-544' }
)
$privSids = @($privGroups | ForEach-Object { $_.Id })
$builtinAdminSid = "$domSid-500"
foreach ($p in $privGroups) {
    try {
        $g = Get-ADGroup -Identity $p.Id -ErrorAction Stop
        $members = @(Get-ADGroupMember -Identity $g -ErrorAction Stop)
        $unexpected = @()
        $business = @()
        foreach ($m in $members) {
            $msid = $m.SID.Value
            if ($msid -eq $builtinAdminSid) { continue }
            if ($privSids -contains $msid) { continue }
            if ($BusinessGroupPattern -and $m.objectClass -eq 'group' -and $m.SamAccountName -match $BusinessGroupPattern) { $business += $m.SamAccountName; continue }
            if ($AllowedPrivileged -contains $m.SamAccountName) { continue }
            $unexpected += $m.SamAccountName
        }
        if ($business.Count -gt 0) { Write-Check FAIL "$($p.Name) contient des groupes metier : $($business -join ', ')" }
        if ($unexpected.Count -gt 0) { Write-Check WARN "$($p.Name) contient des comptes inattendus : $($unexpected -join ', ')" }
        if ($business.Count -eq 0 -and $unexpected.Count -eq 0) { Write-Check PASS "$($p.Name) : composition conforme ($($members.Count) membre(s))" }
    }
    catch { Write-Check FAIL "$($p.Name) illisible : $($_.Exception.Message)" }
}

# ============================================================================= bilan
Write-Host ''
Write-Host ("Bilan : {0} PASS, {1} WARN, {2} FAIL" -f $script:Count.PASS, $script:Count.WARN, $script:Count.FAIL) -ForegroundColor Cyan
if ($script:Count.FAIL -gt 0) { exit 1 }
exit 0