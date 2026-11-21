# CloudGuard 360 — Phase 04 FINAL (novembre 2026)

## Démarrage rapide : un seul ZIP, une seule commande guidée

**Préconditions** : vous êtes dans Azure Cloud Shell **Bash**, avec accès à `rg-cg360-app/ca-cg360-voting`, compte GitHub `NabilNet` connecté avec `gh auth login`, et Terraform disponible. Le dépôt doit exister : https://github.com/NabilNet/cloudguard360-phase04.

1. Téléchargez `CloudGuard360_Phase04_FINAL_2026.zip` sur votre ordinateur.
2. Azure Portal → **Cloud Shell → Bash → Manage files → Upload**. Sélectionnez le fichier ZIP. Ne sélectionnez pas votre ancien ZIP Phase 04.
3. Copiez ce bloc :

```bash
mountpoint -q "$HOME/clouddrive" || { echo 'STOP: stockage persistant absent'; exit 1; }
mkdir -p "$HOME/clouddrive/cloudguard360"
unzip -n "$HOME/CloudGuard360_Phase04_FINAL_2026.zip" -d "$HOME/clouddrive/cloudguard360"
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_FINAL_2026"
bash automation/phase04.sh doctor --repo NabilNet/cloudguard360-phase04
```

4. Quand `doctor` se termine par `PASS`, lancez **une seule commande de finalisation** :

```bash
bash automation/phase04.sh all --repo NabilNet/cloudguard360-phase04
```

5. Répondez `YES` **uniquement après avoir relu** chaque changement demandé. Vous devrez rendre la **package de démonstration GHCR publique** après sa publication, en suivant l'instruction du script. Le code source et les images seront publics, n'y mettez aucune donnée confidentielle.
6. Le script s'arrête automatiquement si Azure, GitHub, Terraform, le test Docker, la sécurité ou les permissions échouent. **Il ne force jamais un déploiement** en contournant une erreur.

## Reprise après incident, sans recommencer

```bash
bash automation/phase04.sh prepare   --repo NabilNet/cloudguard360-phase04
bash automation/phase04.sh ci        --repo NabilNet/cloudguard360-phase04
bash automation/phase04.sh identity  --repo NabilNet/cloudguard360-phase04
bash automation/phase04.sh publish   --repo NabilNet/cloudguard360-phase04
bash automation/phase04.sh deploy    --repo NabilNet/cloudguard360-phase04
bash automation/phase04.sh verify    --repo NabilNet/cloudguard360-phase04
bash automation/phase04.sh reconcile --repo NabilNet/cloudguard360-phase04
```

* Chaque étape vérifie l'état réel avant de changer quoi que ce soit. Elle n'exécute aucun `terraform destroy`, aucune suppression de Resource Group ni aucun `git push --force`.
* **La réussite réelle de la Phase 04 dépend** de votre droit de `roleAssignments/write` sur la Container App, des politiques GitHub du dépôt, de la disponibilité des services et de l'état de votre Phase 03.
* Les fichiers Terraform Phase 01, 02 et 03 ne sont jamais remplacés. `reconcile` modifie uniquement la variable locale `frontend_image` de la Phase 03, sur confirmation, avec sauvegarde, puis lance un **plan sans apply**.

Lire ensuite `GUIDE_COMPLET_FR.md`, `docs/TROUBLESHOOTING_FR.md` ou `index.html` (cours HTML hors ligne).
