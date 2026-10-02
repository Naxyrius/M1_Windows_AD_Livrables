#Requires -Modules ActiveDirectory
<#
    Importe les utilisateurs de users.csv dans l'AD.

Attendu :
    - SamAccountName : prenom.nom (minuscules, sans accents)
    - UPN            : prenom.nom@novacorp.test
    - Mot de passe à changer à la première connexion
    - Compte activé, attribut Department renseigné
    - OU cible : OU=<Department>,OU=NovaCorp,<BaseDN>

    Le script est rejouable : un compte déjà existant est ignoré.

#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CsvPath = 'C:\Users\Administrateur\Documents\users.csv',
    [string]$UpnSuffix = 'novacorp.test',
    [string]$BaseDN = (Get-ADDomain).DistinguishedName,
    [string]$RootOU = 'NovaCorp',
    [SecureString]$InitialPassword = (Read-Host "Mot de passe par défaut (l'utilisateur devra le changer à la première connexion)" -AsSecureString)
)

$ErrorActionPreference = 'Stop'

function ConvertTo-AsciiLower([string]$Text) {
    $decomposed = $Text.Trim().Normalize([Text.NormalizationForm]::FormD)
    $sb = [Text.StringBuilder]::new()
    foreach ($c in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') {
            [void]$sb.Append($c)
        }
    }
    ($sb.ToString() -replace '[^a-zA-Z-]', '').ToLower()
}

# Structure d'OU : NovaCorp > Direction / Finance / IT / RH / Support
function Get-TargetOU([string]$Department) {
    "OU=$Department,OU=$RootOU,$BaseDN"
}

function Test-OUExists([string]$Dn) {
    [bool](Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$Dn'" -ErrorAction SilentlyContinue)
}

# Le CSV est en UTF-8 avec BOM, séparateur « ; »
$users = Import-Csv -Path $CsvPath -Delimiter ';' -Encoding UTF8

$report = foreach ($u in $users) {
    $first = $u.Firstname.Trim()
    $last  = $u.Lastname.Trim()
    $dept  = $u.Department.Trim()

    $sam = '{0}.{1}' -f (ConvertTo-AsciiLower $first), (ConvertTo-AsciiLower $last)
    $upn = "$sam@$UpnSuffix"
    $ou  = Get-TargetOU -Department $dept

    $status = 'Créé'
    try {
        if ($sam.Length -gt 20) {
            throw "SamAccountName trop long ($($sam.Length) > 20 caractères)"
        }
        elseif (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
            $status = 'Ignoré (existe déjà)'
        }
        elseif (-not (Test-OUExists $ou)) {
            throw "L'OU n'existe pas : $ou"
        }
        else {
            $params = @{
                Name                  = "$first $last"
                GivenName             = $first
                Surname               = $last
                DisplayName           = "$first $last"
                SamAccountName        = $sam
                UserPrincipalName     = $upn
                Department            = $dept
                Path                  = $ou
                AccountPassword       = $InitialPassword
                ChangePasswordAtLogon = $true
                Enabled               = $true
            }
            if ($PSCmdlet.ShouldProcess($sam, "Créer le compte dans $ou")) {
                New-ADUser @params
            }
            else {
                $status = 'Simulé (WhatIf)'
            }
        }
    }
    catch {
        $status = "Erreur : $($_.Exception.Message)"
    }

    [pscustomobject]@{
        SamAccountName = $sam
        UPN            = $upn
        OU             = $ou
        Statut         = $status
    }
}

$report | Format-Table -AutoSize

$errors = @($report | Where-Object Statut -like 'Erreur*').Count
Write-Host ("{0} ligne(s) traitée(s), {1} erreur(s)." -f @($report).Count, $errors)