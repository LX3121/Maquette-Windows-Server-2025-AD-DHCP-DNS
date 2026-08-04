<#
.SYNOPSIS
    Création automatisée d'utilisateurs AD directement dans leur OU de département.
#>

# ==========================================================
# 1. Paramètres généraux
# ==========================================================
$CheminCSV           = "C:\Scripts\nouveaux_collaborateurs.csv"
$DomaineAD            = "entreprise.local"
$BaseOU              = "DC=entreprise,DC=local"  # Racine de ton domaine
$MotDePasseTemporaire = "Password2026!"

Import-Module ActiveDirectory

# Fonction pour supprimer les accents du prénom/nom avant de créer le login
function Remove-Accents {
    param ([string]$String)
    $Normalized = $String.Normalize([System.Text.NormalizationForm]::FormD)
    $StringBuilder = New-Object System.Text.StringBuilder
    foreach ($Char in $Normalized.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($Char) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$StringBuilder.Append($Char)
        }
    }
    return $StringBuilder.ToString() -replace '[^a-zA-Z0-9]', ''
}

# ==========================================================
# 2. Vérification du CSV
# ==========================================================
if (-not (Test-Path $CheminCSV)) {
    Write-Host "Fichier introuvable : $CheminCSV" -ForegroundColor Red
    exit
}

$Collaborateurs = Import-Csv -Path $CheminCSV -Delimiter ";"

# ==========================================================
# 3. Traitement
# ==========================================================
foreach ($Collab in $Collaborateurs) {

    $Prenom      = $Collab.Prenom
    $Nom         = $Collab.Nom
    $Departement = $Collab.Departement.Trim()

    # Nettoyage pour le login (ex: Sophie -> smartin)
    $PrenomClean = Remove-Accents -String $Prenom
    $NomClean    = Remove-Accents -String $Nom
    $Identifiant = ($PrenomClean.Substring(0,1) + $NomClean).ToLower()

    # Chemin cible : OU=RH,DC=entreprise,DC=local ou OU=Technique,DC=entreprise,DC=local
    $TargetOU = "OU=$Departement,$BaseOU"

    # Vérification si l'OU existe bien dans l'AD
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$TargetOU'" -ErrorAction SilentlyContinue)) {
        Write-Host "L'OU '$Departement' ($TargetOU) n'existe pas ! Utilisateur $Identifiant ignoré." -ForegroundColor Red
        continue
    }

    # Vérification si le compte existe déjà
    if (Get-ADUser -Filter "SamAccountName -eq '$Identifiant'" -ErrorAction SilentlyContinue) {
        Write-Host "Le compte '$Identifiant' existe déjà -> ignoré." -ForegroundColor Yellow
        continue
    }

    # Création de l'utilisateur dans son OU spécifique
    try {
        New-ADUser `
            -Name                   "$Prenom $Nom" `
            -GivenName              $Prenom `
            -Surname                $Nom `
            -SamAccountName         $Identifiant `
            -UserPrincipalName      "$Identifiant@$DomaineAD" `
            -Path                   $TargetOU `
            -AccountPassword        (ConvertTo-SecureString $MotDePasseTemporaire -AsPlainText -Force) `
            -ChangePasswordAtLogon  $true `
            -Enabled                $true `
            -Department             $Departement

        Write-Host "Compte créé : $Identifiant dans l'OU '$Departement'" -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de la création de $Identifiant : $_" -ForegroundColor Red
        continue
    }

    # Ajout au groupe de sécurité correspondant
    try {
        Add-ADGroupMember -Identity $Departement -Members $Identifiant -ErrorAction Stop
        Write-Host "  -> Ajouté au groupe '$Departement'" -ForegroundColor Cyan
    }
    catch {
        Write-Host "  -> Impossible d'ajouter au groupe '$Departement' : $_" -ForegroundColor Red
    }
}

Write-Host "`nTraitement terminé !" -ForegroundColor Green