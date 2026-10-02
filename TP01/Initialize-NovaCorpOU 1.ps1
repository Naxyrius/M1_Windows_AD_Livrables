Import-Module ActiveDirectory

# Nom de l'OU racine
$ouName = "NovaCorp"
$ouPath = "OU=$ouName,DC=novacorp,DC=test"

# Vérifie si l'OU existe déjà
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase "DC=novacorp,DC=test" -ErrorAction SilentlyContinue)) {
    Write-Host "Création de l'OU $ouName..."
    New-ADOrganizationalUnit -Name $ouName -Path "DC=novacorp,DC=test"
} else {
    Write-Host "L'OU $ouName existe déjà, aucune création."
}

# Arborescence Interne
$subOUs = @("RH", "IT", "Finance", "Direction", "Support")

foreach ($subOU in $subOUs) {
    $subOUPath = "OU=$subOU,$ouPath"
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$subOU'" -SearchBase $ouPath -ErrorAction SilentlyContinue)) {
        Write-Host "Création de l'OU $subOU..."
        New-ADOrganizationalUnit -Name $subOU -Path $ouPath
    } else {
        Write-Host "L'OU $subOU existe déjà, aucune création."
    }
}