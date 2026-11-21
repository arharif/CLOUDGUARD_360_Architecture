# Dépannage précis — CloudGuard 360 Phase 04

### « OWNER/cloudguard360-phase04 not found »
Utilisez toujours `--repo NabilNet/cloudguard360-phase04`. `OWNER` était un placeholder. Vérifiez `gh repo view NabilNet/cloudguard360-phase04`.

### « Expected official sample main.py not found »
L'application officielle se trouve dans `azure-vote/azure-vote/main.py`, et non `azure-vote/main.py`. Ce ZIP teste le chemin correct et tous les assets. Vérifiez avec `find ~/clouddrive/cloudguard360/azure-voting-app-redis-upstream -name main.py -print`. **Ne remplacez pas un fichier manquant par un autre fichier inconnu**.

### `gh: command not found`
Installer le CLI depuis la [documentation officielle](https://cli.github.com/manual/installation) dans Cloud Shell (si les permissions et le gestionnaire de paquets le permettent). Solution alternative : GitHub UI pour préparer le dépôt, mais l'automatisation `all` exige `gh`.

### GitHub login → `credentials saved in plain text`
Avertissement, non erreur. Votre token GitHub CLI peut être conservé en clair dans `~/.config/gh/hosts.yml`. Ne copiez jamais ce fichier dans un ZIP ou dépôt. Déconnectez-vous avec `gh auth logout` si nécessaire ; surveillez l'accès à Cloud Shell.

### Permissions GitHub : « cannot push »
Le compte actuellement authentifié avec `gh` doit pouvoir écrire dans le dépôt. `gh auth status`, puis `gh api repos/NabilNet/cloudguard360-phase04 --jq .permissions`. Si plusieurs comptes, choisissez le bon : `gh auth switch`.

### Azure app absent ou image de la Phase 03 indisponible
Vérifiez `az containerapp show -n ca-cg360-voting -g rg-cg360-app`. Le ZIP Phase 04 **ne crée pas** l'app : il faut terminer la Phase 03 d'abord. Si la Phase 03 utilise encore la vieille image MCR supprimée, la nouvelle image publiée à GHCR doit être opérationnelle avant toute mise à jour ; le déploiement CI pourra ensuite remplacer le frontend défaillant.

### GitHub OIDC : `AADSTS700213` / `No matching federated identity record`
Les nouveaux dépôts GitHub (depuis juillet 2026) ont un `sub` contenant des IDs immuables. Le workflow `00-oidc-subject.yml` imprime `CG360_OIDC_SUBJECT=...`. Comparez cette chaîne **exacte** avec le `subject` Terraform et l'issuer/audience. Ne remplacez pas le `sub` par un nom de repo non identifié ; ne publiez jamais le JWT complet.

### `terraform apply`: `AuthorizationFailed` ou `roleAssignments/write`
Il manque un privilège pour créer l'identité UAMI, le credential fédéré ou l'affectation de rôle au scope. Demandez à l'administrateur Azure d'appliquer les opérations approuvées. Un simple rôle Contributor n'accorde pas toujours `roleAssignments/write`. Ne donnez pas Owner à toute la souscription juste pour cet exercice.

### GHCR « image pull unauthorized » ou Docker pull demande un login
GitHub → profil → **Packages → cloudguard360-vote → Package settings → Visibility: Public**. Ne donnez pas vos identifiants personnels au registre Azure public. Le workflow 03-deploy vérifie le **pull anonyme** en premier.

### GitHub Actions ne démarre pas
Vérifiez que les workflows `.github/workflows/` sont poussés sur `main` et que les Actions sont autorisées par les paramètres du dépôt. Depuis GitHub → Actions, lancez manuellement le workflow voulu, ou `gh workflow list -R NabilNet/cloudguard360-phase04`.

### Docker smoke-test échoue, connexion Redis impossible
Ouvrez les logs du job GitHub CI. Vérifiez les variables `REDIS=cg360-ci-redis` lors du test ou `REDIS=localhost` sur Azure. `docker logs cg360-ci-front` et `docker logs cg360-ci-redis` sont affichés si nécessaire.

### `Azure ContainerApp update` ne modifie pas la bonne image
Le pipeline exige la présence de `vote-frontend` et `redis`, puis utilise explicitement `--container-name vote-frontend`. Si votre Phase 03 utilise d'autres noms, arrêtez-vous et comparez la topologie ; ne renommez pas les ressources en production à l'aveugle.

### Terraform Phase 03 affiche une différence après déploiement GitHub
C'est une dérive de configuration attendue après une modification hors Terraform. Lancez `reconcile` pour sauvegarder puis mettre à jour uniquement `frontend_image`, ensuite **relisez `terraform plan`**. Ne lancez pas un apply destructif.

### Nom `uami-cg360-phase04` déjà existant
Le nouveau Terraform root n'a pas automatiquement le state d'un ancien package. **Ne supprimez pas l'identité**. Un opérateur doit examiner l'ancien Terraform State et envisager un import contrôlé dans le nouveau root s'il s'agit bien de la même ressource. Ne faites pas gérer le même objet par deux États Terraform.

### Résultats sécurité et coûts
La CI peut rester verte malgré des CVE dans l'image, car le scan CVE est informatif. Consultez le rapport et appliquez les corrections. Consultez le portail Azure **Cost Management** : les ressources Azure et le stockage Cloud Shell ne sont pas garantis gratuits.
