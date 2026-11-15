# CloudGuard 360 — Phase 03 | Runbook de dépannage & récupération

**Version :** 1.0 · **Date de rédaction :** 15 novembre 2026 · **Langue :** français · **Environnement :** Azure Cloud Shell (Bash), Terraform, Azure Container Apps, frontend Docker, Redis.

> **État du laboratoire : partiellement validé, pas encore clôturé.** Les sorties réellement fournies confirment une Container App provisionnée (`Succeeded`), une révision active et saine (`Healthy`), HTTP `200`, un frontend *Hello World* et un Redis répondant `PONG`. Elles **ne confirment pas** que le frontend de vote *Cats vs Dogs* a été correctement déployé, qu'un vote est enregistré dans Redis, ni qu'un `terraform plan` final est sans dérive. Après une déconnexion de Cloud Shell pendant la préparation du déploiement du frontend, l'état final de Terraform doit être **réinspecté avant tout nouvel `apply`**.

**Principe de sécurité :** cette procédure n'exécute aucune destruction de Resource Group, VNet, environnement Container Apps, groupe Entra ou affectation RBAC. Ne pas effacer `terraform.tfstate`, ne pas exécuter `terraform destroy`, ne pas appliquer un plan inconnu et ne pas recopier de valeurs sensibles dans un dépôt public.

---

## 01 — Synthèse exécutive et contexte technique

| Élément | État confirmé à partir des sorties utilisateur | Niveau de preuve |
|---|---|---|
| Azure Resource Group | `rg-cg360-app` | Confirmé par les commandes réalisées |
| Azure Container App | `ca-cg360-voting` (région `northeurope`) | Confirmé |
| Azure Container Apps Environment | `cae-cg360-lab` dans Terraform Phase 03 | Création prévue ; existence exacte à confirmer dans le State |
| Image frontend actuellement montrée dans le diagnostic | `mcr.microsoft.com/k8se/quickstart:latest` | Confirmé lors du contrôle utilisateur |
| Image Redis | `redis:7-alpine` | Confirmé |
| Provisionnement | `Succeeded` | Confirmé |
| Révision | Active = `True`, Health = `Healthy` | Confirmé |
| Endpoint | HTTPS, HTTP `200` | Confirmé |
| Application web | *Hello World* Quickstart | Confirmé auparavant, pas une application de vote |
| Redis | `redis-cli ping` → `PONG` | Confirmé |
| Frontend de vote *Cats vs Dogs* | État après tentative de correctif inconnu | **NON VALIDÉ** |
| Terraform sans dérive | Résultat final de `terraform plan` non fourni | **NON VALIDÉ** |

### Architecture cible et distinctions

```text
Navigateur HTTPS
     |
     v
Azure Container App : ca-cg360-voting
  +--------------------------------------------------+
  | vote-frontend (:80)                              |
  |    - état précédent : Quickstart / Hello World    |
  |    - cible : vrai formulaire Cats vs Dogs         |
  |    - dépend du processus Python/Flask             |
  |             |                                    |
  |             v                                    |
  |  Redis sidecar (:6379, accès interne uniquement)  |
  +--------------------------------------------------+
       |
     Container Apps Environment : cae-cg360-lab
       |
     Resource Group déjà existant : rg-cg360-app
```

Les deux conteneurs sont dans **la même Container App** : ils partagent des ressources réseau et leur cycle de vie, ce qui permet au frontend de contacter Redis via `localhost:6379` **si son code utilise bien ce nom d'hôte**. Cette architecture *lab* n'est pas une solution de production : Redis n'a pas de persistance durable, le frontend est public et l'intégration à la VNet Phase 01 n'a pas été réalisée.

### Ce que prouve un HTTP 200

- `HTTP 200` : **l'endpoint web répond**.
- `Healthy` : **une révision s'est déclarée saine**.
- `PONG` : **le processus Redis répond**.
- Aucun de ces contrôles ne prouve qu'une requête POST de vote écrit dans la file Redis.

---

## 02 — Chronologie réelle des incidents et causes

| Référence | Symptôme | Diagnostic documenté | Mesure déjà réalisée / état |
|---|---|---|---|
| **INC-03-01** | `MANIFEST_UNKNOWN` pour `mcr.microsoft.com/azuredocs/azure-vote-front:v1` | Le registre ne fournissait pas ce manifeste avec le tag demandé. Azure ne pouvait pas créer de révision exploitable. | Image remplacée par Microsoft Quickstart pour rétablir un déploiement de démonstration. **Résolu pour le démarrage du conteneur.** |
| **INC-03-02** | `resource already exists ... needs to be imported into the State` | L'objet Azure existait après une création partielle, mais n'était pas référencé sous `azurerm_container_app.voting` dans le Terraform State utilisé. | Procédure de récupération/import appliquée ; le provisionnement a ensuite réussi. Il faut toujours vérifier le State actif. |
| **INC-03-03** | L'URL affiche *Hello World* au lieu du vote | L'image Quickstart sert une page de démonstration, **pas** un frontend de vote connecté à Redis. | Azure/HTTPS validés. **Fonctionnalité vote non validée.** |
| **INC-03-04** | Impossible de prouver le fonctionnement Redis par la simple URL | Le frontend Quickstart n'utilise pas Redis ; `HTTP 200` est insuffisant. | Test `az containerapp exec ... redis-cli ping` retournant **`PONG`**. Redis opérationnel, mais liaison de vote non prouvée. |
| **INC-03-05** | Cloud Shell s'est déconnecté pendant « Contrôler le plan et appliquer » | Une cause probable est `set -euo pipefail` utilisé dans la session **interactive** : un contrôle Python avec code retour ≠ 0 peut déclencher la fermeture du shell. Une interruption propre à Cloud Shell reste également possible. | **Récupération non destructive nécessaire.** Ne pas supposer qu'`apply` a eu lieu, ni qu'il a échoué. |
| **INC-03-06** | Adaptateur proposé pour l'image Docker Samples | Le code de `dockersamples/example-voting-app` utilise `Redis(host="redis")`, alors que les conteneurs de notre ACA partagent `localhost`. Un patch au démarrage a été proposé. | **Changement non validé dans Azure dans les sorties reçues.** Ne pas présenter le digest ou l'adaptateur comme une réussite observée. |

### Chaîne de causalité

```text
IMAGE TAG ABSENT
   ↓
ÉCHEC DE LA PREMIÈRE CRÉATION
   ↓
OBJET AZURE ÉVENTUELLEMENT PRÉSENT MAIS ABSENT DU TF STATE
   ↓
« RESOURCE ALREADY EXISTS » AU DEUXIÈME APPLY
   ↓
RÉCONCILIATION / RÉCUPÉRATION DE L'APPLICATION
   ↓
QUICKSTART DÉPLOYÉ : Succeeded + Healthy + HTTP 200
   ↓
REDIS TESTÉ : PONG
   ↓
TENTATIVE DE PASSAGE À L'IMAGE DE VOTE
   ↓
DÉCONNEXION CLOUD SHELL PENDANT LE CONTRÔLE
   ↓
ÉTAT COURANT INCONNU → REPRISE EN LECTURE SEULE AVANT TOUT APPLY
```

---

## 03 — Reprise immédiate de Cloud Shell (5 vérifications, sans modification)

**N'exécuter que de petites commandes séparées.** Ces commandes conviennent à Cloud Shell **Bash** ; elles ne déploient ni ne suppriment de ressource.

### 03.1 — Rouvrir le bon terminal

1. Dans [Azure Portal](https://portal.azure.com/), sélectionner l'icône **Cloud Shell** puis **Bash**.
2. Ne pas relancer `az login` si Cloud Shell utilise déjà l'authentification du portail.
3. Vérifier que `~/clouddrive` est monté (sinon, ne pas continuer avec Terraform).
4. Éviter de coller un grand bloc dont chaque erreur pourrait fermer le shell.

```bash
# Réinitialiser les options éventuellement héritées de commandes précédentes
set +e
set +u
set +o pipefail
```

> **Pourquoi c'est important :** `set -e` dans **un shell interactif** peut provoquer sa sortie lorsqu'une commande renvoie un statut non nul. Utiliser `set -euo pipefail` à l'intérieur d'un **script exécuté dans un sous-processus** (`bash ./script.sh`) est différent : en cas d'échec, le script se termine mais n'est pas censé fermer le shell parent. Il peut aussi y avoir une déconnexion Cloud Shell indépendante (inactivité, interruption de session). Ne pas affirmer que `set -e` était la cause certaine.

### 03.2 — Confirmer le bon environnement

```bash
mountpoint -q "$HOME/clouddrive" && echo "STORAGE OK" || echo "STOP : Cloud Shell non persistant"
```

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform
pwd
```

```bash
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
az account show --query '{Name:name,State:state}' -o table
```

**Attendu :** même dossier Phase 03, souscription activée, fichiers persistants. Aucun identifiant de souscription à publier.

### 03.3 — Vérifier l'inventaire Terraform

```bash
terraform state list
```

Vérifier notamment :

```text
azurerm_container_app_environment.lab
azurerm_container_app.voting
```

Les `data.azurerm_*` peuvent également apparaître ; ce sont des références en lecture seule. Si `azurerm_container_app.voting` est absent alors que l'application existe dans Azure, passer à **04.2 Import**, pas à `terraform apply`.

### 03.4 — Vérifier la configuration réellement présente dans Azure

```bash
az containerapp show -g rg-cg360-app -n ca-cg360-voting \
  --query '{Name:name,Provisioning:properties.provisioningState,LatestRevision:properties.latestRevisionName}' -o table
```

```bash
az containerapp show -g rg-cg360-app -n ca-cg360-voting \
  --query 'properties.template.containers[].{Name:name,Image:image,Command:command}' -o json
```

```bash
az containerapp revision list -g rg-cg360-app -n ca-cg360-voting \
  --query '[].{Name:name,Active:properties.active,Health:properties.healthState}' -o table
```

**Décision :** si le frontend affiche toujours Quickstart, le vote n'est pas déployé. S'il affiche une image Docker Samples et que la révision est dégradée, regarder les journaux avant toute modification.

### 03.5 — Vérifier les fichiers Terraform sans les modifier

```bash
terraform validate
```

```bash
grep -n 'frontend_image' terraform.tfvars
grep -n 'CG360-VOTE-ADAPTER' main.tf || echo 'Adaptateur non détecté dans main.tf'
```

`grep` peut retourner `1` lorsqu'il n'y a pas de correspondance : **ce n'est pas une raison de fermer Cloud Shell**.

---

## 04 — Arbre de décision : ressource Azure vs Terraform State

### 04.1 — Cas A : application présente dans le State

Si `terraform state list` contient **`azurerm_container_app.voting`**, **ne pas réimporter**. Continuer avec un nouveau `terraform plan`.

### 04.2 — Cas B : application présente dans Azure, absente du State

**Uniquement dans le Terraform root original de Phase 03** :

```bash
APP_ID="$(az containerapp show -g rg-cg360-app -n ca-cg360-voting --query id -o tsv)"
```

```bash
terraform import azurerm_container_app.voting "$APP_ID"
```

```bash
terraform state list
```

**But :** importer **une seule** ressource existante sous **une seule** adresse Terraform. Un import ajoute l'objet distant au State ; **il ne rend pas automatiquement la configuration conforme**. Il faut vérifier le plan ensuite. Si la ressource est déjà suivie ailleurs, résoudre cette divergence au préalable.

### 04.3 — Cas C : application introuvable dans Azure mais présente dans le State

C'est une possible **dérive externe**. Ne pas lancer de création automatiquement. Inspecter l'historique des changements et l'Azure Activity Log. Protéger l'environnement et vérifier que le bon abonnement et le bon State sont utilisés.

### 04.4 — Cas D : application absente dans Azure et dans le State

Un nouveau déploiement est possible, mais seulement à partir d'une image valide et après un plan complet. Éviter l'ancienne image MCR avec `v1` qui a déjà échoué.

---

## 05 — Plan Terraform : procédure sûre après une déconnexion

> **Point clé :** `terraform plan` n'effectue pas de changement. `terraform apply` peut en effectuer. Le plan doit être **refait et inspecté** si l'état de Terraform ou Azure est incertain. Ne pas réutiliser un ancien plan enregistré avant la déconnexion.

### 05.1 — Calculer un nouveau plan

```bash
terraform plan -out=phase03-recovery-review.tfplan
```

Vérifier l'existence du plan :

```bash
ls -lh phase03-recovery-review.tfplan
```

Afficher un résumé :

```bash
terraform show -no-color phase03-recovery-review.tfplan | grep -E 'will be created|will be updated|must be replaced|will be destroyed|Plan:'
```

Afficher **le plan complet** (à conserver en privé) :

```bash
terraform show -no-color phase03-recovery-review.tfplan
```

| Résultat | Décision |
|---|---|
| `No changes` + vraie interface de vote + POST/Redis OK | Préparer la clôture ; ne pas réappliquer |
| `No changes` + image Quickstart | Terraform est synchronisé avec **Hello World**, pas avec le vote |
| `0 add, 1 change, 0 destroy` sur `azurerm_container_app.voting` | Candidat à la mise à jour ; contrôler les champs de l'image et le reste du plan |
| `1 add` sur `azurerm_container_app.voting` alors qu'Azure possède déjà l'app | **STOP** ; importer/réconcilier le State |
| `must be replaced`, `destroy`, nouvelle VNet, nouveau RG, changements IAM | **STOP** ; ne pas appliquer |
| `Error`, plan inexistant ou compte non autorisé | **STOP** ; diagnostiquer l'erreur exacte |

### 05.2 — Contrôle complémentaire de sécurité

Si tu as extrait ce kit dans `~/clouddrive/cloudguard360/CloudGuard360_Phase03_Troubleshooting`, lance :

```bash
terraform show -json phase03-recovery-review.tfplan | python3 \
  ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Troubleshooting/scripts/validate_frontend_plan.py
```

Le vérificateur exige **une unique modification de l'application existante**, les deux conteneurs `vote-frontend` et `redis`, Redis inchangé, le port 80 et l'ingress HTTPS conservés. Il refuse une création, destruction ou modification inattendue. Le résultat `PLAN PASS` n'est **pas** une preuve que l'image distante démarrera ; il complète la revue humaine du plan, sans la remplacer.

**Ne pas exécuter le guard si le plan annonce déjà `No changes`** : dans ce cas il rejettera volontairement puisqu'il est conçu pour une mise à jour de frontend.

### 05.3 — Application uniquement après validation

Si **le plan complet** ne change que le frontend, que l'image est vérifiée et que le contrôle est `PLAN PASS` :

```bash
terraform apply phase03-recovery-review.tfplan
```

**Ne jamais** combiner `terraform apply` avec un contrôle qui peut échouer dans un grand bloc interactif `set -euo pipefail`. Après toute déconnexion, reprendre à **03.3**, pas directement à `apply`.

---

## 06 — Diagnostic fonctionnel : Hello World, vote et Redis

### 06.1 — Vérifier HTTP (sans confondre disponibilité et fonctionnalité)

```bash
URL="$(terraform output -raw app_url)"
curl -L -sS -o /dev/null -w 'HTTP %{http_code}\n' --max-time 45 "$URL/"
```

`HTTP 200` prouve que la page répond, **pas** qu'elle affiche un formulaire de vote.

### 06.2 — Distinguer Hello World du formulaire *Cats vs Dogs*

```bash
curl -fsS --max-time 45 "$URL/" | grep -Eio 'Cats|Dogs|Hello World|Your container app is running' | head -12
```

**Interprétation :** si la page affiche seulement « Your container app is running », c'est encore Quickstart. Si la page comporte les options de vote, continuer au POST. Une absence de correspondance ne prouve pas à elle seule un échec : examiner le HTML et les journaux.

### 06.3 — Vérifier Redis (déjà réalisé et confirmé)

```bash
az containerapp exec -g rg-cg360-app -n ca-cg360-voting \
  --container redis --command 'redis-cli ping'
```

**Résultat utilisateur observé :** `PONG`. C'est la preuve que Redis est accessible dans son conteneur.

### 06.4 — Vérifier un vote réel (NON ENCORE OBSERVÉ)

À exécuter **uniquement si la vraie interface de vote est déployée** et si un vote de test est acceptable :

```bash
curl -sS -o /dev/null -w 'POST vote HTTP %{http_code}\n' --max-time 45 \
  -X POST -d 'vote=a' "$URL/"
```

```bash
az containerapp exec -g rg-cg360-app -n ca-cg360-voting \
  --container redis --command 'redis-cli LLEN votes'
```

Le frontend Docker Samples écrit les votes dans la liste Redis `votes` ; un résultat positif après le POST appuie la validation fonctionnelle. Redis est **volatile** dans cette architecture : si le conteneur redémarre ou si le réplica passe à zéro, la liste peut disparaître.

### 06.5 — Vérifier les journaux Azure

```bash
az containerapp logs show -g rg-cg360-app -n ca-cg360-voting \
  --type system --tail 30
```

```bash
az containerapp logs show -g rg-cg360-app -n ca-cg360-voting \
  --container vote-frontend --tail 40
```

| Trace | Diagnostic probable | Réponse |
|---|---|---|
| `MANIFEST_UNKNOWN`, `ErrImagePull`, `ImagePullBackOff` | Référence d'image absente/inaccessible | Vérifier le nom, le tag ou le digest avant un nouveau plan |
| `CrashLoopBackOff`, `container exited` | Erreur de démarrage du frontend | Vérifier `command`, `args`, dépendances et journaux applicatifs |
| `Connection refused` Redis | Adresse/port incorrect ou service indisponible | Confirmer `localhost:6379` et `PONG` dans la même révision |
| HTTP `502` | Révision non prête, mauvais port, crash | Vérifier revision health et ingress `target_port=80` |
| HTTP `200` + Hello World | Image Quickstart toujours active | Pas d'incident Azure ; la fonctionnalité vote reste à déployer |

---

## 07 — Pourquoi l'adaptateur Docker Samples est un changement sensible

Le dépôt [Docker Samples Example Voting App](https://github.com/dockersamples/example-voting-app) est une application distribuée avec un frontend de vote, Redis, un worker, PostgreSQL et une interface de résultats. **Notre laboratoire n'a que le frontend et Redis** : on peut vérifier l'ajout à la file de votes, mais pas la totalité de l'architecture de résultats.

Les sources publiques actuellement consultées indiquent :

- Le code `vote/app.py` contient `Redis(host="redis", db=0, socket_timeout=5)`.
- Le Dockerfile du frontend utilise `WORKDIR /usr/local/app`, expose le port `80` et lance `gunicorn app:app ...`.
- Deux conteneurs dans la **même** Azure Container App partagent le réseau. Un frontend utilisant strictement `Redis(host="redis")` a donc besoin d'une adaptation pour rejoindre le sidecar via `localhost`.

Le correctif proposé auparavant utilisait `command=["/bin/sh","-c"]` et un script qui modifie `app.py` au démarrage. **Ce correctif reste une hypothèse d'implémentation tant qu'il n'a pas démarré correctement sur la révision Azure et passé le test POST → Redis.** Un digest SHA-256 fourni dans un exemple ne doit pas être traité comme une garantie permanente de disponibilité de l'image.

**Approche recommandée pour stabiliser la Phase 03 :** conserver le déploiement Quickstart en état sain jusqu'à ce que le frontend de vote ait été reconstruit et testé dans une image que vous contrôlez, avec un paramètre `REDIS_HOST=localhost` pris en charge directement par l'application. Pour un laboratoire rapide, une modification contrôlée au démarrage peut suffire, mais elle doit être testée comme une modification de code, avec possibilité de retour arrière.

---

## 08 — Retour arrière contrôlé vers Quickstart

Si l'image de vote est défectueuse, **ne supprimez pas** le Resource Group, l'environnement ou le Terraform State. L'objectif est de revenir au frontend Quickstart déjà observé fonctionnel.

1. Dans le Terraform root Phase 03, vérifier les backups créés par le patch précédent.
2. Comparer les fichiers actuels et les backups **avant** de les restaurer.
3. Si les backups sont bien la version Quickstart, les restaurer dans le même Terraform root.
4. Exécuter `terraform validate`, puis `terraform plan -out=rollback.tfplan` ; la seule modification acceptable est la configuration de `azurerm_container_app.voting`.
5. Appliquer uniquement ce plan vérifié et confirmer une révision saine.

```bash
ls -l main.tf.before-votefix.bak terraform.tfvars.before-votefix.bak
```

```bash
diff -u main.tf.before-votefix.bak main.tf || true
diff -u terraform.tfvars.before-votefix.bak terraform.tfvars || true
```

**Ne pas exécuter de copie automatique des backups si vous avez d'autres changements intentionnels depuis leur création.** Si un retour arrière est décidé, sauvegardez d'abord les versions présentes puis restaurez **seulement** les fichiers reconnus comme appartenant à la version saine. N'exécutez pas `terraform destroy` pour un défaut applicatif.

---

## 09 — Preuves, évaluation des risques et critère de clôture

### Matrice de tests et de preuves

| Test | Commande / preuve | Statut réel au 15/11/2026 |
|---|---|---|
| Infrastructure provisionnée | `az containerapp show` : `Succeeded` | **PASS observé** |
| Révision opérationnelle | `az containerapp revision list` : `Healthy` | **PASS observé** |
| Endpoint HTTPS | `curl` : `200` | **PASS observé** |
| Redis vivant | `redis-cli ping` : `PONG` | **PASS observé** |
| Image de vote déployée | Images de la révision actuelle | **À RECONTRÔLER** après déconnexion |
| Formulaire Cats vs Dogs | HTML réel de l'application | **NON VALIDÉ** |
| Vote enregistré dans Redis | POST + `LLEN votes` | **NON VALIDÉ** |
| Terraform synchronisé | `terraform plan -detailed-exitcode` code `0` | **NON VALIDÉ** |
| Aucune modification Phase 01/02 | Revue Terraform Plan | **À JUSTIFIER** |

### Critère de clôture Phase 03

**VALIDÉE (infrastructure seulement)** : Azure provisionné, révision Healthy, HTTPS 200, Redis PONG.

**VALIDÉE (complète)** : les tests précédents **et** le véritable formulaire de vote, POST HTTP 200, Redis `LLEN votes` cohérent, plan Terraform sans dérive, absence de modifications imprévues de Phase 01/02 et décision de coûts/cleanup documentée.

### Risques résiduels

- **Source d'image Docker** : image publique évolutive ou digest non confirmé, risque de retrait du manifeste.
- **Dérive Terraform** : import dans un mauvais root, plan stale ou interruption pendant une opération.
- **Commandes en session interactive** : `set -euo pipefail` peut provoquer une fermeture inattendue de Bash.
- **Exploitabilité applicative** : HTTP 200 sans test fonctionnel de vote.
- **Données temporaires** : Redis sans volume, pertes au scale-to-zero ou au redémarrage.
- **Exposition publique** : application de démonstration sans authentification, n'y envoyer aucune donnée sensible.

---

## 10 — Raccourci pour le prochain diagnostic (sans appliquer)

Copiez les commandes séparément, dans cet ordre :

```bash
set +e
set +u
set +o pipefail
```

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
```

```bash
terraform state list
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query 'properties.template.containers[].{Name:name,Image:image}' -o table
```

```bash
terraform validate
terraform plan -out=phase03-recovery-review.tfplan
terraform show -no-color phase03-recovery-review.tfplan | grep -E 'will be created|will be updated|must be replaced|will be destroyed|Plan:'
```

**Arrêtez-vous au plan avant toute modification**, et transmettez le **résumé du plan (sans ID/secret)** si une création, un remplacement ou une suppression apparaît. Ne pas exécuter `terraform apply` tant que l'état précis post-déconnexion n'est pas confirmé.

---

## 11 — Sources vérifiables

- [Microsoft Learn — Dépannage des erreurs de déploiement Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/troubleshoot-deployment-errors)
- [Microsoft Learn — Démarrage des conteneurs et diagnostics](https://learn.microsoft.com/en-us/azure/container-apps/troubleshoot-container-start-failures)
- [Microsoft Learn — Plusieurs conteneurs dans une Container App](https://learn.microsoft.com/en-us/azure/container-apps/containers)
- [Microsoft Learn — Caractéristiques et persistance Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)
- [Terraform / HashiCorp — Importer un objet distant dans le State](https://developer.hashicorp.com/terraform/cli/commands/import)
- [Docker Samples — Example Voting App (architecture générale)](https://github.com/dockersamples/example-voting-app)
- [Docker Samples — `vote/app.py` (connexion Redis et file `votes`)](https://github.com/dockersamples/example-voting-app/blob/main/vote/app.py)
- [Docker Samples — `vote/Dockerfile` (répertoire `/usr/local/app`, port 80 et Gunicorn)](https://github.com/dockersamples/example-voting-app/blob/main/vote/Dockerfile)

**Méthodologie :** seuls les résultats explicitement fournis par l'utilisateur sont présentés comme *observés*. Les résultats futurs, la disponibilité d'une image distante et la réussite d'un patch Terraform sont des **critères à vérifier dans la souscription réelle**, pas des faits acquis.
