
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # ===================================================================================== CONFIGURATION

    # ----- Fichier source [PARTAGE]
    [string]$CsvPath,                                  # vide = <dossier du script>\..\datasets\employees.csv
    [string]$CsvDelimiter = ';',
    [string]$CsvEncoding = 'UTF8',
    [string]$ColFirstname = 'Firstname',
    [string]$ColLastname = 'Lastname',
    [string]$ColDepartment = 'Department',
    [string]$ColSite = 'Site',                         # copie dans l'attribut Office ; '' = colonne ignoree
    [string]$ColManager = 'Manager',                   # sAMAccountName du responsable ; '' = colonne ignoree

    # ----- Arborescence, sous la racine du domaine [PARTAGE]
    [string]$RootOU = 'NovaCorp',
    [string]$GroupsOU = 'Groups',                      # OU des groupes de domaine local, sous RootOU
    [string]$DepartmentsParentOU = '',                 # OU intermediaire des services (ex. 'Users') ; '' = directement sous RootOU
    [bool]$GlobalGroupsInDepartmentOU = $true,         # $false = groupes globaux ranges dans GroupsOU
    [bool]$ProtectOUs = $true,                         # protection contre la suppression accidentelle des OU creees

    # ----- Nommage des groupes, {0} = nom du service [PARTAGE]
    [string]$GlobalGroupFormat = 'GG_{0}',
    [string]$ModifyGroupFormat = 'DL_{0}_RW',
    [string]$ReadGroupFormat = 'DL_{0}_R',
    [string]$ReadAllDepartment = 'Direction',          # service qui lit les ressources de tous les autres ; '' = aucun

    # ----- Descriptions des groupes, {0} = nom du service
    [string]$GlobalGroupDescription = 'Metier {0}',
    [string]$ModifyGroupDescription = 'Acces en modification aux ressources {0}',
    [string]$ReadGroupDescription = 'Acces en lecture aux ressources {0}',

    # ----- Comptes, {0} = prenom, {1} = nom [PARTAGE pour les trois premieres valeurs]
    [string]$SamFormat = '{0}.{1}',
    [int]$SamMaxLength = 20,
    [string]$SamInvalidChars = '[^a-z0-9.\-]',         # caracteres retires (apres passage en minuscules et sans accents)
    [string]$NameFormat = '{0} {1}',                   # Name (CN) et DisplayName
    [string]$UpnSuffix,                                # vide = nom DNS du domaine
    [bool]$EnableNewAccounts = $true,
    [bool]$ChangePasswordAtLogon = $true,
    [System.Security.SecureString]$InitialPassword,    # vide = demande en saisie masquee si un compte doit etre cree

    # ----- Journal
    [string]$LogDir,                                   # vide = <dossier du script>\logs
    [string]$LogPrefix = 'deploy'

    # =================================================================================================
)

# ----------------------------------------------------------------------------- chemins par defaut
# $PSScriptRoot peut etre vide dans param() (Windows PowerShell 5.1, ISE) : chemins calcules ici
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }
if (-not $CsvPath) { $CsvPath = Join-Path $scriptDir '..\datasets\employees.csv' }
if (-not $LogDir) { $LogDir = Join-Path $scriptDir 'logs' }

$script:Stats = @{ Created = 0; Updated = 0; Unchanged = 0; Warnings = 0; Errors = 0 }
$script:LogFile = $null
$script:PlannedOUs = @{}    # OU qui seraient creees en -WhatIf (leurs enfants ne peuvent pas etre interroges)

# ----------------------------------------------------------------------------- journalisation
function Write-Log {
    param(
        [Parameter(Mandatory)][ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )
    $colors = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red' }
    Write-Host ('[{0}] {1}' -f $Level, $Message) -ForegroundColor $colors[$Level]
    if ($script:LogFile) {
        $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -WhatIf:$false
    }
    if ($Level -eq 'WARN') { $script:Stats.Warnings++ }
    if ($Level -eq 'ERROR') { $script:Stats.Errors++ }
}

function Test-Apply {
    # Respecte -WhatIf / -Confirm du script
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'Utilise volontairement le $PSCmdlet du script')]
    param([string]$Target, [string]$Action)
    return $PSCmdlet.ShouldProcess($Target, $Action)
}

# ----------------------------------------------------------------------------- utilitaires
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

function ConvertTo-SamAccountName {
    # minuscules, sans accents, caracteres non autorises retires, longueur limitee
    param([string]$Text)
    $s = (Remove-Diacritics $Text.Trim()).ToLower() -replace $SamInvalidChars, ''
    if ($s.Length -gt $SamMaxLength) { $s = $s.Substring(0, $SamMaxLength) }
    return $s.TrimEnd(".", "-")   # AD refuse un sAMAccountName termine par un point
}

function New-SamAccountName {
    param([string]$First, [string]$Last)
    return ConvertTo-SamAccountName ($SamFormat -f $First, $Last)
}

function Get-Field {
    # valeur d'une colonne du CSV, nettoyee ; '' si la colonne n'est pas configuree ou vide
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

# ----------------------------------------------------------------------------- briques idempotentes
function Confirm-OU {
    param([string]$Name, [string]$ParentDN)
    $dn = 'OU={0},{1}' -f $Name, $ParentDN
    if ($script:PlannedOUs.ContainsKey($ParentDN)) {
        # parent seulement prevu (-WhatIf) : impossible d'interroger l'annuaire en dessous
        Write-Log INFO "[WhatIf] OU a creer : $dn"
        $script:PlannedOUs[$dn] = $true
        return $dn
    }
    try {
        $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $ParentDN -SearchScope OneLevel -ErrorAction Stop
        if ($existing) {
            Write-Log OK "OU deja presente : $dn"
            $script:Stats.Unchanged++
        }
        elseif (Test-Apply $dn "Creer l'OU") {
            New-ADOrganizationalUnit -Name $Name -Path $ParentDN -ProtectedFromAccidentalDeletion $ProtectOUs -ErrorAction Stop
            Write-Log OK "OU creee : $dn"
            $script:Stats.Created++
        }
        else {
            Write-Log INFO "[WhatIf] OU a creer : $dn"
            $script:PlannedOUs[$dn] = $true
        }
    }
    catch {
        Write-Log ERROR "OU $dn : $($_.Exception.Message)"
    }
    return $dn
}

function Confirm-Group {
    param(
        [string]$Name,
        [ValidateSet('Global', 'DomainLocal')][string]$Scope,
        [string]$PathDN,
        [string]$Description
    )
    try {
        $g = Get-ADGroup -Filter "Name -eq '$Name'" -Properties Description -ErrorAction Stop
        if ($g) {
            $conform = $true
            if ([string]$g.GroupScope -ne $Scope) {
                Write-Log WARN "Groupe $Name de portee $($g.GroupScope) au lieu de $Scope (non modifie : a corriger manuellement)"
                $conform = $false
            }
            if ($g.Description -ne $Description) {
                if (Test-Apply $Name 'Mettre a jour la description') {
                    Set-ADGroup -Identity $g -Description $Description -ErrorAction Stop
                    Write-Log OK "Description mise a jour : $Name ('$($g.Description)' -> '$Description')"
                    $script:Stats.Updated++
                }
                else { Write-Log INFO "[WhatIf] Description de $Name a mettre a jour : '$Description'" }
                $conform = $false
            }
            if ($conform) {
                Write-Log OK "Groupe deja conforme : $Name ($Scope)"
                $script:Stats.Unchanged++
            }
        }
        elseif (Test-Apply $Name "Creer le groupe $Scope") {
            New-ADGroup -Name $Name -GroupScope $Scope -GroupCategory Security -Path $PathDN -Description $Description -ErrorAction Stop
            Write-Log OK "Groupe cree : $Name ($Scope) dans $PathDN"
            $script:Stats.Created++
        }
        else {
            Write-Log INFO "[WhatIf] Groupe a creer : $Name ($Scope)"
        }
    }
    catch {
        Write-Log ERROR "Groupe $Name : $($_.Exception.Message)"
    }
}

function Add-MemberIfMissing {
    param([string]$GroupName, [string]$MemberDN, [string]$Label)
    try {
        $g = Get-ADGroup -Filter "Name -eq '$GroupName'" -Properties Member -ErrorAction Stop
        if (-not $g) {
            if ($WhatIfPreference) { Write-Log INFO "[WhatIf] $Label serait ajoute a $GroupName (groupe a creer)" }
            else { Write-Log WARN "Groupe $GroupName introuvable, $Label non ajoute" }
            return
        }
        if ($g.Member -contains $MemberDN) {
            Write-Log OK "$Label est deja membre de $GroupName"
            $script:Stats.Unchanged++
        }
        elseif (Test-Apply "$Label -> $GroupName" 'Ajouter au groupe') {
            Add-ADGroupMember -Identity $g -Members $MemberDN -ErrorAction Stop
            Write-Log OK "$Label ajoute a $GroupName"
            $script:Stats.Updated++
        }
        else {
            Write-Log INFO "[WhatIf] $Label serait ajoute a $GroupName"
        }
    }
    catch {
        Write-Log ERROR "Ajout de $Label a $GroupName : $($_.Exception.Message)"
    }
}

function Remove-MemberIfPresent {
    param([string]$GroupName, [string]$MemberDN, [string]$Label)
    try {
        $g = Get-ADGroup -Filter "Name -eq '$GroupName'" -Properties Member -ErrorAction Stop
        if ($g -and ($g.Member -contains $MemberDN)) {
            if (Test-Apply "$Label <- $GroupName" 'Retirer du groupe') {
                Remove-ADGroupMember -Identity $g -Members $MemberDN -Confirm:$false -ErrorAction Stop
                Write-Log WARN "$Label retire de $GroupName (ne correspond plus a son service)"
                $script:Stats.Updated++
            }
            else {
                Write-Log INFO "[WhatIf] $Label serait retire de $GroupName"
            }
        }
    }
    catch {
        Write-Log ERROR "Retrait de $Label de $GroupName : $($_.Exception.Message)"
    }
}

# ============================================================================= programme principal
try {
    if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force -WhatIf:$false | Out-Null }
    $script:LogFile = Join-Path $LogDir ('{0}-{1}.log' -f $LogPrefix, (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
catch {
    Write-Host "[WARN] Journal fichier indisponible ($($_.Exception.Message)) : journal console uniquement" -ForegroundColor Yellow
}

Write-Log INFO "Deploy-NovaCorp demarre (WhatIf=$([bool]$WhatIfPreference))"

# --- prerequis : annuaire
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
}
catch {
    Write-Log ERROR "Module ActiveDirectory ou domaine indisponible : $($_.Exception.Message)"
    exit 2
}
$domainDN = $domain.DistinguishedName
$dnsRoot = $domain.DNSRoot
if (-not $UpnSuffix) { $UpnSuffix = $dnsRoot }
Write-Log INFO "Domaine : $dnsRoot ($domainDN), suffixe UPN : $UpnSuffix"

# --- prerequis : CSV
if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Log ERROR "Fichier CSV introuvable : $CsvPath"
    exit 2
}
try {
    $raw = @(Import-Csv -LiteralPath $CsvPath -Delimiter $CsvDelimiter -Encoding $CsvEncoding -ErrorAction Stop)
}
catch {
    Write-Log ERROR "Lecture du CSV impossible : $($_.Exception.Message)"
    exit 2
}
if ($raw.Count -eq 0) {
    Write-Log ERROR "Le CSV est vide : $CsvPath"
    exit 2
}
$headers = @($raw[0].PSObject.Properties | ForEach-Object { $_.Name })
$missing = @(@($ColFirstname, $ColLastname, $ColDepartment) | Where-Object { $headers -notcontains $_ })
if ($missing.Count -gt 0) {
    Write-Log ERROR "Colonne(s) obligatoire(s) absente(s) : $($missing -join ', ') (colonnes trouvees : $($headers -join ', ') ; separateur '$CsvDelimiter')"
    exit 2
}
if ($ColSite -and ($headers -notcontains $ColSite)) {
    Write-Log WARN "Colonne '$ColSite' absente du CSV : attribut Office non gere"
    $ColSite = ''
}
if ($ColManager -and ($headers -notcontains $ColManager)) {
    Write-Log WARN "Colonne '$ColManager' absente du CSV : attribut Manager non gere"
    $ColManager = ''
}
$rows = @($raw | Where-Object { (Get-Field $_ $ColFirstname) -and (Get-Field $_ $ColLastname) -and (Get-Field $_ $ColDepartment) })
if ($rows.Count -eq 0) {
    Write-Log ERROR "Le CSV ne contient aucune ligne exploitable (prenom, nom et service requis)"
    exit 2
}
$departments = @($rows | ForEach-Object { Get-Field $_ $ColDepartment } | Sort-Object -Unique)
Write-Log INFO ("CSV : {0} utilisateur(s), {1} service(s) : {2}" -f $rows.Count, $departments.Count, ($departments -join ', '))

# --- 1. OU
Write-Log INFO '--- 1. Unites d''organisation'
$rootDN = Confirm-OU -Name $RootOU -ParentDN $domainDN
$groupsDN = Confirm-OU -Name $GroupsOU -ParentDN $rootDN
$deptParentDN = if ($DepartmentsParentOU) { Confirm-OU -Name $DepartmentsParentOU -ParentDN $rootDN } else { $rootDN }
$deptOU = @{}
foreach ($d in $departments) { $deptOU[$d] = Confirm-OU -Name $d -ParentDN $deptParentDN }

# --- 2. Groupes
Write-Log INFO '--- 2. Groupes metier'
foreach ($d in $departments) {
    $ggPath = if ($GlobalGroupsInDepartmentOU) { $deptOU[$d] } else { $groupsDN }
    Confirm-Group -Name ($GlobalGroupFormat -f $d) -Scope Global -PathDN $ggPath -Description ($GlobalGroupDescription -f $d)
    Confirm-Group -Name ($ModifyGroupFormat -f $d) -Scope DomainLocal -PathDN $groupsDN -Description ($ModifyGroupDescription -f $d)
    Confirm-Group -Name ($ReadGroupFormat -f $d) -Scope DomainLocal -PathDN $groupsDN -Description ($ReadGroupDescription -f $d)
}

# --- 3. AGDLP
Write-Log INFO '--- 3. Imbrication AGDLP (global -> domaine local)'
foreach ($d in $departments) {
    $ggName = $GlobalGroupFormat -f $d
    $rwName = $ModifyGroupFormat -f $d
    try {
        $gg = Get-ADGroup -Filter "Name -eq '$ggName'" -ErrorAction Stop
        if ($gg) { Add-MemberIfMissing -GroupName $rwName -MemberDN $gg.DistinguishedName -Label $ggName }
        elseif ($WhatIfPreference) { Write-Log INFO "[WhatIf] $ggName serait imbrique dans $rwName" }
        else { Write-Log WARN "$ggName introuvable : imbrication dans $rwName impossible" }
    }
    catch { Write-Log ERROR "Imbrication $ggName : $($_.Exception.Message)" }
}
if (-not $ReadAllDepartment) {
    Write-Log INFO 'Lecture transverse desactivee (ReadAllDepartment vide)'
}
elseif ($departments -contains $ReadAllDepartment) {
    $readAllName = $GlobalGroupFormat -f $ReadAllDepartment
    try {
        $ggRead = Get-ADGroup -Filter "Name -eq '$readAllName'" -ErrorAction Stop
        foreach ($d in ($departments | Where-Object { $_ -ne $ReadAllDepartment })) {
            $rName = $ReadGroupFormat -f $d
            if ($ggRead) { Add-MemberIfMissing -GroupName $rName -MemberDN $ggRead.DistinguishedName -Label $readAllName }
            elseif ($WhatIfPreference) { Write-Log INFO "[WhatIf] $readAllName serait imbrique dans $rName" }
        }
    }
    catch { Write-Log ERROR "Imbrication lecture transverse : $($_.Exception.Message)" }
}
else {
    Write-Log WARN "Le service '$ReadAllDepartment' est absent du CSV : pas d'acces en lecture transverse configure"
}

# --- 4. Utilisateurs (creation et correction de derive)
Write-Log INFO '--- 4. Utilisateurs'
$userDN = @{}
foreach ($row in $rows) {
    $first = Get-Field $row $ColFirstname
    $last = Get-Field $row $ColLastname
    $dept = Get-Field $row $ColDepartment
    $site = Get-Field $row $ColSite
    $sam = New-SamAccountName -First $first -Last $last
    $name = $NameFormat -f $first, $last
    $ouDN = $deptOU[$dept]
    try {
        $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties Department, Office, Enabled -ErrorAction Stop
        if (-not $u) {
            if (-not $InitialPassword -and -not $WhatIfPreference) {
                $InitialPassword = Read-Host -AsSecureString 'Mot de passe initial des nouveaux comptes'
            }
            if (Test-Apply $sam 'Creer l''utilisateur') {
                $new = @{
                    Name                  = $name
                    GivenName             = $first
                    Surname               = $last
                    DisplayName           = $name
                    SamAccountName        = $sam
                    UserPrincipalName     = "$sam@$UpnSuffix"
                    Department            = $dept
                    Path                  = $ouDN
                    AccountPassword       = $InitialPassword
                    Enabled               = $EnableNewAccounts
                    ChangePasswordAtLogon = $ChangePasswordAtLogon
                }
                if ($site) { $new['Office'] = $site }
                New-ADUser @new -ErrorAction Stop
                $created = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction Stop
                $userDN[$sam] = $created.DistinguishedName
                Write-Log OK "Utilisateur cree : $sam ($dept)"
                $script:Stats.Created++
            }
            else {
                $userDN[$sam] = "CN=$name,$ouDN"
                Write-Log INFO "[WhatIf] Utilisateur a creer : $sam ($dept)"
            }
            continue
        }

        # utilisateur existant : controle de derive
        $currentDN = $u.DistinguishedName
        $changed = $false
        $set = @{}
        if ($u.Department -ne $dept) {
            Write-Log WARN "Derive : $sam Department '$($u.Department)' -> '$dept'"
            $set['Department'] = $dept
        }
        if ($site -and ($u.Office -ne $site)) {
            Write-Log WARN "Derive : $sam Office '$($u.Office)' -> '$site'"
            $set['Office'] = $site
        }
        if ($set.Count -gt 0) {
            if (Test-Apply $sam 'Corriger les attributs') {
                Set-ADUser -Identity $currentDN @set -ErrorAction Stop
                Write-Log OK "Attributs corriges : $sam ($($set.Keys -join ', '))"
                $script:Stats.Updated++
            }
            else { Write-Log INFO "[WhatIf] Attributs a corriger : $sam" }
            $changed = $true
        }
        $parent = Get-ParentDN $currentDN
        if ($parent -ne $ouDN) {
            Write-Log WARN "Derive : $sam est dans '$parent' au lieu de '$ouDN'"
            if (Test-Apply $sam "Deplacer vers $ouDN") {
                Move-ADObject -Identity $currentDN -TargetPath $ouDN -ErrorAction Stop
                $currentDN = 'CN={0},{1}' -f ($currentDN -split '(?<!\\),', 2)[0].Substring(3), $ouDN
                Write-Log OK "Utilisateur deplace : $sam -> $ouDN"
                $script:Stats.Updated++
            }
            else { Write-Log INFO "[WhatIf] $sam serait deplace vers $ouDN" }
            $changed = $true
        }
        if (-not $u.Enabled) {
            Write-Log WARN "Le compte $sam est desactive (non modifie : a verifier manuellement)"
        }
        $userDN[$sam] = $currentDN
        if (-not $changed) {
            Write-Log OK "Utilisateur conforme : $sam"
            $script:Stats.Unchanged++
        }
    }
    catch {
        Write-Log ERROR "Utilisateur $sam : $($_.Exception.Message)"
    }
}

# --- 5. Appartenances aux groupes de service
Write-Log INFO '--- 5. Appartenances aux groupes de service'
foreach ($row in $rows) {
    $dept = Get-Field $row $ColDepartment
    $sam = New-SamAccountName -First (Get-Field $row $ColFirstname) -Last (Get-Field $row $ColLastname)
    if (-not $userDN.ContainsKey($sam)) { continue }
    Add-MemberIfMissing -GroupName ($GlobalGroupFormat -f $dept) -MemberDN $userDN[$sam] -Label $sam
    foreach ($other in ($departments | Where-Object { $_ -ne $dept })) {
        Remove-MemberIfPresent -GroupName ($GlobalGroupFormat -f $other) -MemberDN $userDN[$sam] -Label $sam
    }
}

# --- 6. Responsables hierarchiques
if ($ColManager) {
    Write-Log INFO '--- 6. Responsables (attribut Manager)'
    foreach ($row in $rows) {
        $managerRaw = Get-Field $row $ColManager
        if (-not $managerRaw) { continue }
        $sam = New-SamAccountName -First (Get-Field $row $ColFirstname) -Last (Get-Field $row $ColLastname)
        $mSam = ConvertTo-SamAccountName $managerRaw
        try {
            $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties Manager -ErrorAction Stop
            if (-not $u) { continue }   # utilisateur non cree (WhatIf)
            $m = Get-ADUser -Filter "SamAccountName -eq '$mSam'" -ErrorAction Stop
            if (-not $m) {
                Write-Log WARN "Responsable '$mSam' de $sam introuvable dans l'annuaire"
                continue
            }
            if ($u.Manager -eq $m.DistinguishedName) {
                Write-Log OK "Responsable deja correct : $sam -> $mSam"
                $script:Stats.Unchanged++
            }
            elseif (Test-Apply $sam "Definir le responsable $mSam") {
                Set-ADUser -Identity $u.DistinguishedName -Manager $m.DistinguishedName -ErrorAction Stop
                Write-Log OK "Responsable defini : $sam -> $mSam"
                $script:Stats.Updated++
            }
            else { Write-Log INFO "[WhatIf] Responsable de $sam serait : $mSam" }
        }
        catch {
            Write-Log ERROR "Responsable de $sam : $($_.Exception.Message)"
        }
    }
}

# --- bilan
$s = $script:Stats
Write-Log INFO ("Bilan : {0} cree(s), {1} modifie(s), {2} inchange(s), {3} avertissement(s), {4} erreur(s)" -f $s.Created, $s.Updated, $s.Unchanged, $s.Warnings, $s.Errors)
if ($script:LogFile) { Write-Host "Journal : $script:LogFile" }
if ($s.Errors -gt 0) { exit 1 }
exit 0