
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # ===================================================================================== CONFIGURATION

    # ----- Foret a creer
    [ValidatePattern('^[a-z0-9-]+(\.[a-z0-9-]+)+$')]
    [string]$DomainName = 'novacorp.test',
    [ValidatePattern('^[a-z0-9-]{1,15}$')]
    [string]$NetbiosName = 'NOVACORP',
    [string]$ForestMode = '',                          # ex. 'WinThreshold' ; '' = niveau par defaut de l'OS
    [string]$DomainMode = '',                          # ex. 'WinThreshold' ; '' = niveau par defaut de l'OS
    [bool]$InstallDns = $true,

    # ----- Emplacements de la base AD ('' = emplacements par defaut sous C:\Windows)
    [string]$DatabasePath = '',
    [string]$AdLogPath = '',
    [string]$SysvolPath = '',

    # ----- Securite
    [System.Security.SecureString]$SafeModePassword,   # vide = demande en saisie masquee au moment de la promotion

    # ----- Controles prealables
    [string]$DefaultNamePattern = 'WIN-*',             # nom de serveur considere comme "non renomme" ; '' = pas de controle
    [bool]$RequireStaticIP = $false,                   # $true = une IP en DHCP bloque la promotion (sinon simple avertissement)

    # ----- Journal
    [string]$LogDir,                                   # vide = <dossier du script>\logs
    [string]$LogPrefix = 'install'

    # =================================================================================================
)

# $PSScriptRoot peut etre vide dans param() (Windows PowerShell 5.1, ISE) : chemin calcule ici
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }
if (-not $LogDir) { $LogDir = Join-Path $scriptDir 'logs' }

$script:LogFile = $null

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
}

function Test-Apply {
    # Respecte -WhatIf / -Confirm du script
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'Utilise volontairement le $PSCmdlet du script')]
    param([string]$Target, [string]$Action)
    return $PSCmdlet.ShouldProcess($Target, $Action)
}

function Import-ModuleQuiet {
    # En -WhatIf, les scripts de chargement d'un module heritent de la simulation
    # et affichent des lignes "Definir l'alias" : on charge le module hors simulation.
    param([string]$Name)
    $WhatIfPreference = $false
    Import-Module $Name -ErrorAction Stop
}

# ============================================================================= programme principal
try {
    if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force -WhatIf:$false | Out-Null }
    $script:LogFile = Join-Path $LogDir ('{0}-{1}.log' -f $LogPrefix, (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
catch {
    Write-Host "[WARN] Journal fichier indisponible ($($_.Exception.Message)) : journal console uniquement" -ForegroundColor Yellow
}

$NetbiosName = $NetbiosName.ToUpper()
$DomainName = $DomainName.ToLower()
Write-Log INFO "Install-NovaCorpAD demarre (domaine $DomainName / $NetbiosName, WhatIf=$([bool]$WhatIfPreference))"

# --- 1. prerequis bloquants
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log ERROR 'Le script doit etre lance en tant qu''administrateur'
    exit 2
}
if (-not (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue)) {
    Write-Log ERROR 'Windows Server requis (Install-WindowsFeature introuvable)'
    exit 2
}

try {
    Import-ModuleQuiet CimCmdlets
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
}
catch {
    Write-Log ERROR "Lecture de la configuration systeme impossible : $($_.Exception.Message)"
    exit 2
}
# DomainRole : 0/2 = autonome, 1/3 = membre d'un domaine, 4/5 = controleur de domaine
if ($cs.DomainRole -ge 4) {
    if ($cs.Domain -ieq $DomainName) {
        Write-Log OK "Ce serveur est deja controleur du domaine $DomainName : rien a faire"
        Write-Log INFO 'Etape suivante : .\Deploy-NovaCorp.ps1 -WhatIf'
        exit 0
    }
    Write-Log ERROR "Ce serveur est deja controleur du domaine '$($cs.Domain)' (attendu : '$DomainName') : arret"
    exit 2
}
if ($cs.PartOfDomain) {
    Write-Log ERROR "Ce serveur est membre du domaine '$($cs.Domain)' : une nouvelle foret se cree sur un serveur hors domaine"
    exit 2
}
Write-Log OK "Serveur autonome ($env:COMPUTERNAME) : promotion possible"

# --- 2. prerequis recommandes (non bloquants)
if ($DefaultNamePattern -and ($env:COMPUTERNAME -like $DefaultNamePattern)) {
    Write-Log WARN "Nom par defaut ($env:COMPUTERNAME) : le renommer AVANT la promotion (Rename-Computer puis redemarrage), c'est penible apres"
}
try {
    # filtrage apres coup : avec des filtres en parametres, l'absence de resultat leve une erreur
    $dhcp = @(Get-NetIPInterface -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.Dhcp -eq 'Enabled' -and $_.ConnectionState -eq 'Connected' -and $_.InterfaceAlias -notlike 'Loopback*' })
    if ($dhcp.Count -gt 0) {
        $msg = "IPv4 en DHCP sur : $(($dhcp | ForEach-Object { $_.InterfaceAlias }) -join ', ') (un controleur de domaine doit avoir une IP fixe)"
        if ($RequireStaticIP) {
            Write-Log ERROR $msg
            exit 2
        }
        Write-Log WARN $msg
    }
    else { Write-Log OK 'Adressage IPv4 fixe' }
}
catch { Write-Log WARN "Verification de l'adressage IP impossible : $($_.Exception.Message)" }

# --- 3. role AD DS
try {
    $feature = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction Stop
    if ($feature.Installed) {
        Write-Log OK 'Role AD DS deja installe'
    }
    elseif (Test-Apply 'AD-Domain-Services' 'Installer le role et les outils d''administration') {
        Write-Log INFO 'Installation du role AD DS (quelques minutes)...'
        $r = Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
        if (-not $r.Success) {
            Write-Log ERROR "Installation du role AD DS echouee (ExitCode : $($r.ExitCode))"
            exit 1
        }
        Write-Log OK 'Role AD DS installe'
        if ([string]$r.RestartNeeded -eq 'Yes') {
            Write-Log WARN 'Redemarrage requis avant la promotion : redemarrer puis relancer ce script'
            exit 0
        }
    }
    else {
        Write-Log INFO '[WhatIf] Role AD DS a installer (avec les outils d''administration)'
    }
}
catch {
    Write-Log ERROR "Role AD DS : $($_.Exception.Message)"
    exit 1
}

# --- 4. promotion en controleur d'une nouvelle foret
if ($WhatIfPreference -and -not $feature.Installed) {
    Write-Log INFO "[WhatIf] Foret $DomainName a creer (prerequis non testables tant que le role n'est pas installe)"
    exit 0
}

if (-not $SafeModePassword) {
    $SafeModePassword = Read-Host -AsSecureString 'Mot de passe DSRM (mode restauration des services d''annuaire)'
}
$forestParams = @{
    DomainName                    = $DomainName
    DomainNetbiosName             = $NetbiosName
    InstallDns                    = $InstallDns
    SafeModeAdministratorPassword = $SafeModePassword
}
if ($ForestMode) { $forestParams['ForestMode'] = $ForestMode }
if ($DomainMode) { $forestParams['DomainMode'] = $DomainMode }
if ($DatabasePath) { $forestParams['DatabasePath'] = $DatabasePath }
if ($AdLogPath) { $forestParams['LogPath'] = $AdLogPath }
if ($SysvolPath) { $forestParams['SysvolPath'] = $SysvolPath }

try {
    Import-ModuleQuiet ADDSDeployment

    if ($WhatIfPreference) {
        $t = Test-ADDSForestInstallation @forestParams -ErrorAction Stop
        if ([string]$t.Status -eq 'Success') { Write-Log OK "[WhatIf] Prerequis de promotion valides : la foret $DomainName pourrait etre creee" }
        else {
            Write-Log ERROR "[WhatIf] Prerequis de promotion non remplis : $($t.Message)"
            exit 1
        }
    }
    elseif (Test-Apply $DomainName 'Creer la foret et promouvoir ce serveur (redemarrage automatique)') {
        $t = Test-ADDSForestInstallation @forestParams -ErrorAction Stop
        if ([string]$t.Status -ne 'Success') {
            Write-Log ERROR "Prerequis de promotion non remplis : $($t.Message)"
            exit 1
        }
        Write-Log WARN "Promotion de $env:COMPUTERNAME en controleur de $DomainName : le serveur va redemarrer"
        Write-Log INFO 'Apres redemarrage, se connecter en NOVACORP\Administrateur puis lancer .\Deploy-NovaCorp.ps1 -WhatIf'
        $res = Install-ADDSForest @forestParams -Force -ErrorAction Stop
        if ($res -and [string]$res.Status -ne 'Success') {
            Write-Log ERROR "Promotion echouee : $($res.Message)"
            exit 1
        }
    }
    else {
        Write-Log INFO 'Promotion annulee'
    }
}
catch {
    Write-Log ERROR "Promotion : $($_.Exception.Message)"
    exit 1
}
exit 0
