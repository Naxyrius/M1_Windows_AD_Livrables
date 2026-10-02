# TP6-Livrable

## Activation de la corbeille via Powershell ou GUI

### GUI
AD Administrative Center > novacorp (local) > Activer la Corbeille

### PS
```PowerShell
Enable-ADOptionalFeature -Identity "CN=Recycle Bin Feature,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=novacorp,DC=test" -Scope ForestOrConfigurationSet -Target "novacorp.test"
```

## Restaurer un élément supprimé
Exemple avec Inès Fournier supprimée

### GUI
AD Administrative Center > novacorp (local) > Deleted Users > clic droit sur l'objet supprimé > Resteurer

### PowerShell
```PowerShell
Get-ADObject -Filter 'SamAccountName -eq "ines.fournier"' -IncludeDeletedObjects | Restore-ADObject
```

## PSO sur groupe GG_LabAdmins

#Création de la politique (priorité plus basse = prévalence plus forte)
```PowerShell
New-ADFineGrainedPasswordPolicy -Name "PSO_GG_LabAdmins" `
    -Precedence 10 `
    -MinPasswordLength 14 `
    -PasswordHistoryCount 24 `
    -ComplexityEnabled $true `
    -LockoutThreshold 5 `
    -LockoutObservationWindow "00:15:00" `
    -LockoutDuration "00:30:00"
```

# Application au groupe
```PowerShell
Add-ADFineGrainedPasswordPolicySubject -Identity "PSO_GG_LabAdmins" -Subjects "GG_LabAdmins"

#Vérification de l'application sur un utilisateur du groupe
PS C:\WINDOWS\system32> Get-ADUserResultantPasswordPolicy -Identity "lea.richard"


AppliesTo                   : {CN=GG_LabAdmins,OU=IT,OU=NovaCorp,DC=novacorp,DC=test}
ComplexityEnabled           : True
DistinguishedName           : CN=PSO_GG_LabAdmins,CN=Password Settings Container,CN=System,DC=novacorp,DC=test
LockoutDuration             : 00:30:00
LockoutObservationWindow    : 00:15:00
LockoutThreshold            : 5
MaxPasswordAge              : 42.00:00:00
MinPasswordAge              : 1.00:00:00
MinPasswordLength           : 14
Name                        : PSO_GG_LabAdmins
ObjectClass                 : msDS-PasswordSettings
ObjectGUID                  : ca489472-3afd-44a8-8f51-eec86740c119
PasswordHistoryCount        : 24
Precedence                  : 10
ReversibleEncryptionEnabled : True
```

## Audit des utilisateurs privilégiés
```PowerShell
$PrivilegedGroups = @("Admins du domaine", "Administrateurs de l'entreprise", "Adminitrateurs du schéma")
$Report = foreach ($Group in $PrivilegedGroups) {
    try {
        $Members = Get-ADGroupMember -Identity $Group -Recursive
        foreach ($Member in $Members) {
            [PSCustomObject]@{
                Group            = $Group
                MemberName       = $Member.name
                SamAccountName   = $Member.SamAccountName
                ObjectClass      = $Member.objectClass
            }
        }
    } catch {
        Write-Warning "Impossible de lire le groupe : $Group"
    }
}

Write-Output $Report

Group             MemberName     SamAccountName ObjectClass
-----             ----------     -------------- -----------
Admins du domaine Administrateur Administrateur user       
Admins du domaine Leo            Leo            user       
Admins du domaine Axel axel      axel           user
```


## gMSA

### Ajout de la KDS root key (Key Distribution System)
La clé permet au service KDS de genérer les mots de passe du compte gMSA

```PowerShell
PS C:\WINDOWS\system32> Add-KdsRootKey –EffectiveTime ((Get-Date).AddHours(-10))

Guid
----
8baa7307-97c8-0075-8c1d-29797c4afc81

PS C:\WINDOWS\system32> Get-KdsRootKey

AttributeOfWrongFormat :
KeyValue               : {106, 193, 180, 108...}
EffectiveTime          : 02/10/2026 04:46:03
CreationTime           : 02/10/2026 14:46:03
IsFormatValid          : True
DomainController       : CN=DC01,OU=Domain Controllers,DC=novacorp,DC=test
ServerConfiguration    : Microsoft.KeyDistributionService.Cmdlets.KdsServerConfiguration
KeyId                  : 8baa7307-97c8-0075-8c1d-29797c4afc81
VersionNumber          : 1
```

### Installation sur le SRV01
```PowerShell
PS C:\WINDOWS\system32> Install-ADServiceAccount -Identity "gmsa_svc01"
PS C:\WINDOWS\system32> Test-ADServiceAccount -Identity "gmsa_svc01"
True
```

Il est préferable d'utiliser un gMSA plûtot qu'un svc avec 'PasswordNeverExpires'car il est normalement non interactif (on ne peut pas ouvrir de session) et le mot de passe est renouvelé régulièrement et inconnu des utilisateurs.