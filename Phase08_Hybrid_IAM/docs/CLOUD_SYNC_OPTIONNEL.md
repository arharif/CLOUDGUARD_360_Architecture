# Option avancée : réelle synchronisation AD DS → Microsoft Entra avec Cloud Sync

**Ne pas confondre cet exercice avec la comparaison de fichiers CSV/JSON.** Le laboratoire principal crée un domaine AD DS local et audite Entra en lecture seule, sans agent de synchronisation.

## Prérequis à valider séparément

- Forêt Active Directory saine, DNS/UPN documentés, domaine public vérifié dans Entra pour les identités interactives si nécessaire.
- Un serveur Windows **joint au domaine**, avec les versions système supportées, pouvant joindre le contrôleur de domaine et atteindre les points de terminaison Microsoft via TLS 1.2/accès sortant.
- Un compte avec les permissions Microsoft Entra **Hybrid Identity Administrator**, non invité, et des permissions AD suffisantes pour l'installation/configuration du service (gMSA).
- Licences Entra adaptées aux fonctionnalités utilisées, vérifiées **pour le tenant réel**.
- Une OU pilote isolée, un groupe pilote et une autorisation explicite avant activation du provisioning ; ne pas synchroniser toute une forêt de production par défaut.
- Journaux et plan de rollback. Ne pas installer le provisioning agent sur un DC de production sans étude d'architecture.

## Étapes de déploiement réel (avec la documentation officielle ouverte)

1. Vérifier les prérequis à la source : https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-prerequisites
2. Choisir une architecture de test selon le tutoriel : https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/tutorial-single-forest
3. Installer l'agent Windows supporté sur une machine jointe au domaine et ayant les accès sortants requis : https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-install
4. Dans Microsoft Entra Admin Center, accéder à **Entra ID → Entra Connect → Cloud Sync**, créer une configuration de provisioning **AD vers Entra**, sélectionner le domaine et les OU/groupes pilotes uniquement.
5. Utiliser les fonctions de test de provisioning sur une identité pilote, puis examiner les journaux d'erreurs et les transformations d'attributs : https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-configure
6. Après approbation, activer le scope strictement nécessaire, observer le premier cycle de provisioning et son delta, vérifier que les utilisateurs attendus existent dans Entra et qu'ils possèdent une source `onPremisesSyncEnabled` appropriée.
7. Vérifier la gestion du départ d'un compte selon le produit et les procédures de désactivation. Ne jamais présumer qu'une action AD se propage instantanément ou que les sessions cloud sont automatiquement révoquées.

## Limites de ce package

- **Aucun agent Cloud Sync n'est fourni ni installé**.
- Les comptes `@corp.cg360.test` ne doivent pas être présentés comme des identités cloud avec domaine vérifié.
- Les **quatre groupes Azure existants** de la Phase 02 ne deviennent pas soudainement des copies synchronisées des quatre groupes AD créés localement ; une synchronisation réelle créerait/relierait des objets suivant les règles du produit. Eviter les doublons, collisions et modifications de Source of Authority.
- Aucune activation ou exécution de cette option n'est possible sans votre environnement, accès et approbations. C'est un plan de mise en œuvre, pas une preuve de succès.
