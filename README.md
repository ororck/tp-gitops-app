# tp-gitops-app

## Ce que c'est

Le code de l'application du TP GitOps et sa chaîne d'intégration continue. Trois services Go sont construits dans une seule image Docker.

## Ce que ça fait

| Service | Binaire | Route | Variables |
|---|---|---|---|
| api | `/app/api` | `GET /data` | `BOOKS_API_HOST`, `MOVIES_API_HOST` |
| books | `/app/books` | `GET /books` | aucune |
| movies | `/app/movies` | `GET /movies` | aucune |

L'API Gateway interroge les services `books` et `movies` et agrège leurs réponses. Chaque service écoute sur le port 8080, modifiable avec `PORT`. Les variables `BOOKS_API_HOST` et `MOVIES_API_HOST` prennent la forme `nom-du-service:8080`, sans schéma.

À chaque push sur `main`, la CI construit l'image et la pousse sur le registre `acrmsaidigitops`. Le tag est le SHA court du commit, jamais `latest`.

## Comment ça marche

L'image contient les trois binaires et n'a pas de `ENTRYPOINT`. Chaque Deployment choisit son binaire avec le champ `command`.

Le workflow `.github/workflows/build-push.yml` fait deux choses.

1. Sur toute pull request, il vérifie le `Dockerfile` avec hadolint
2. Sur un push vers `main`, il se connecte à Azure, construit l'image et la pousse

La connexion à Azure passe par OIDC, sans secret de longue durée. Le script `scripts/oidc.sh` crée l'enregistrement d'application, les federated credentials et le rôle `AcrPush` sur le registre. Deux credentials existent, car les dépôts récents présentent un sujet au format immuable avec les identifiants du compte et du dépôt. Le script peut être relancé sans risque.

Les identifiants du client, du tenant et de l'abonnement sont des variables du dépôt GitHub, pas des secrets.

Le workflow affiche le tag produit en fin de job. Il est ensuite reporté dans le dépôt `tp-gitops-manifests`, le passage de la CI à la CD restant manuel.

## Dépendances

- Go pour le code des services
- Docker pour construire l'image
- Azure CLI et les droits nécessaires pour lancer `scripts/oidc.sh`
- Le registre `acrmsaidigitops`
- Le dépôt `tp-gitops-manifests`, qui consomme l'image
