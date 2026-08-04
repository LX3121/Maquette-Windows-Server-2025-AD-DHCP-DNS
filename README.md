# Maquette Système & Réseau : Windows Server 2025 + Client Windows 10

## Description du Projet

Ce projet personnel vise à concevoir et déployer une infrastructure réseau d'entreprise virtualisée sous **VMware Workstation**. L'objectif principal est de simuler un environnement professionnel pour comprendre les interactions fondamentales entre un serveur contrôleur de domaine et un poste client.

En tant que candidat à un poste de **Technicien Support**, cette maquette m'a permis de pratiquer concrètement la gestion centralisée des utilisateurs et des ressources réseau.

---

## Stack Technique & Outils

* **Hyperviseur :** VMware Workstation Pro
* **Serveur :** Windows Server 2025 (Évaluation)
* **Poste Client :** Windows 10 Enterprise (22H2)
* **Rôles & Services Déployés :**
  * **AD DS** (Active Directory Domain Services)
  * **DNS** (Domain Name System)
  * **DHCP** (Dynamic Host Configuration Protocol)

---

## Configuration Réseau (Logique)

Afin d'assurer la stabilité des services critiques (AD, DNS), une configuration IP statique a été appliquée sur le serveur.

| Composant | Nom d'hôte | Rôle | IP / Masque | Passerelle (NAT) | DNS |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Serveur DC** | `SERVEUR-TEST` | DC / DNS / DHCP | `192.168.238.128` / 24 | `192.168.238.2` | `192.168.238.2` |
| **Domaine AD** | `entreprise.local` | - | - | - | - |
| **Poste Client** | `Machine Jean DUPONT` | Client Joint | Dynamique (DHCP) | Fournie par DHCP | Fournie par DHCP |

---

## Chronologie du Déploiement & Explications Techniques

Cette section détaille les étapes techniques réalisées et la logique d'ingénierie appliquée à chaque phase.

### Phase 1 : Préparation & Installation

L'environnement virtuel a été dimensionné pour garantir la stabilité des services Active Directory et DHCP (4 Go de RAM et 2 vCPU attribués à la machine virtuelle serveur). L'installation de Windows Server 2025 et de Windows 10 a été effectuée à partir des images ISO d'évaluation officielles de Microsoft.

![Installation Windows Server 2025](images/capture01_install_server.png)

### Phase 2 : Configuration Initiale du Serveur

Un contrôleur de domaine nécessite une configuration fixe et prévisible avant sa mise en service :

1. **IP Statique :** L'attribution de l'adresse fixe `192.168.238.128` garantit que le serveur reste joignable en permanence par les postes clients pour l'authentification et la résolution DNS.
2. **VMware Tools :** Déploiement des pilotes pour optimiser l'intégration réseau et les performances de la machine virtuelle.
3. **Mises à jour système :** Application des derniers correctifs de sécurité avant la promotion du serveur.

La configuration de l'adaptateur réseau a été validée via la commande `ipconfig /all`.

![Validation IP Fixe Serveur](images/capture02_valid_ip_fixe.png)

### Phase 3 : Installation des Rôles (AD DS, DNS, DHCP)

La centralisation de la gestion des utilisateurs repose sur le service **Active Directory (AD DS)**, qui requiert le rôle **DNS** pour la localisation des services d'authentification (Kerberos, LDAP). Le rôle **DHCP** a également été installé sur ce serveur pour automatiser l'attribution des adresses IP sur le réseau.

L'installation a été réalisée via l'assistant du Gestionnaire de serveur en incluant les outils d'administration distante (RSAT).

![Sélection des rôles Serveur](images/capture03_select_roles.png)

### Phase 4 : Configuration Étendue DHCP

L'automatisation de l'adressage IP des postes clients s'articule autour des paramètres suivants :

1. **Plage d'adressage :** Création de l'étendue nommée `Reseau-Local`.
2. **Exclusions d'adresses :** Exclusion explicite de l'adresse IP du serveur (`192.168.238.128`) de la plage d'attribution pour prévenir tout conflit d'IP.
3. **Options d'étendue :** Configuration de la passerelle par défaut (`192.168.238.2`) transmise automatiquement aux équipements du réseau.

![Configuration DHCP Gateway](images/capture04_dhcp_gateway.png)

### Phase 5 : Administration Active Directory

L'annuaire Active Directory permet de centraliser les identités des collaborateurs. Depuis la console "Utilisateurs et ordinateurs Active Directory" (ADUC), un compte utilisateur de test (`jdupont@entreprise.local`) a été créé pour simuler l'intégration d'un nouvel employé.

![Création Utilisateur Jean Dupont](images/capture05_ad_user_jdupont.png)

### Phase 6 : Déploiement Client & Jonction

Cette étape valide l'interconnexion globale des services de la maquette :

1. Le service **DHCP** attribue une adresse IP dynamique au poste Windows 10.
2. Le service **DNS** résout le nom de domaine `entreprise.local`.
3. L'**Active Directory** valide la jonction de la machine et permet l'ouverture de session du compte `jdupont`.

La commande `whoami` exécutée sur le poste client confirme que la session est bien ouverte sous l'autorité du domaine (`entreprise\jdupont`).

![Validation whoami entreprise\jdupont](images/capture06_whoami_validation.png)

---

## Conclusion & Apprentissage

Ce projet m'a permis de mettre en pratique les concepts fondamentaux de l'administration système : l'interaction entre le DHCP, le DNS et Active Directory lors de l'intégration d'un poste de travail. Cette réalisation constitue une base solide pour la gestion de parc informatique et le support utilisateur en entreprise.

# Document Technique : Automatisation du Provisioning Active Directory via PowerShell

Ce document détaille la démarche de création automatisée de comptes utilisateurs Active Directory à partir d'un fichier CSV, de la préparation des scripts sur le serveur jusqu'à la vérification de l'arborescence AD DS.

---

## 1. Préparation de l'environnement local et des fichiers

Les scripts de provisioning ainsi que le fichier source `nouveaux_collaborateurs.csv` sont hébergés localement sur le contrôleur de domaine dans le répertoire dédié `C:\Scripts`.

* **`ADUsers.ps1`** : Script PowerShell assurant la lecture du CSV, la création des comptes dans les bonnes Unités d'Organisation (OU) et l'affectation aux groupes de sécurité.
* **`nouveaux_collaborateurs.csv`** : Fichier source contenant la liste des collaborateurs, leurs départements et leurs identifiants.

![Répertoire C:\Scripts contenant le script PowerShell et le fichier CSV source](images/3.png)

---

## 2. État initial de la structure Active Directory

Avant l'exécution du script, l'annuaire Active Directory est structuré avec des Unités d'Organisation par service (`RH` et `Technique`). Chaque OU contient initialement son groupe de sécurité respectif, mais aucun compte utilisateur n'y est encore présent.

### Unité d'Organisation RH (État initial)
![Console dsa.msc montrant l'OU RH contenant uniquement le groupe de sécurité RH](images/1.png)

### Unité d'Organisation Technique (État initial)
![Console dsa.msc montrant l'OU Technique contenant uniquement le groupe de sécurité Technique](images/2.png)

---

## 3. Exécution du script PowerShell d'automatisation

Le script `ADUsers.ps1` est exécuté depuis une console Windows PowerShell en privilèges administrateur (`C:\Scripts`).

### Actions réalisées par le script :
* **Parsing du CSV** : Extraction des informations de chaque collaborateur.
* **Génération du login** : Création automatique du `SamAccountName` (ex: `smartin`, `lbernard`, `epetit`).
* **Création des comptes** : Ajout des comptes utilisateurs directement dans l'OU cible (`OU=RH` ou `OU=Technique`).
* **Affectation aux groupes** : Ajout automatique des utilisateurs aux groupes de sécurité associés à leur service.
* **Vérification CLI** : Contrôle immédiat en fin d'exécution via la commande `Get-ADGroupMember` pour confirmer l'appartenance aux groupes `RH` et `Technique`.

![Exécution du script dans PowerShell et vérification des membres des groupes RH et Technique](images/4.png)

---

## 4. Vérification et validation dans la console Active Directory

Après exécution du script, les comptes sont contrôlés dans la console *Utilisateurs et ordinateurs Active Directory* (`dsa.msc`).

### Validation de l'OU RH
Les utilisateurs **Sophie Martin** (`smartin`) et **Emma Petit** (`epetit`) ont été créés et rattachés au groupe de sécurité `RH`.

![Console dsa.msc confirmant la présence des comptes Sophie Martin et Emma Petit dans l'OU RH](images/5.png)

### Validation de l'OU Technique
L'utilisateur **Lucas Bernard** (`lbernard`) a été créé et rattaché au groupe de sécurité `Technique`.

![Console dsa.msc confirmant la présence du compte Lucas Bernard dans l'OU Technique](images/6.png)
