# compta-multi — logiciel de comptabilité multi-sociétés (cabinet externe)

Application web destinée aux **comptables externes** : une base et une interface
séparées du portail interne, pour que le cabinet travaille sans accéder au reste.
Toute l'interface est **en français**.

## Nature du projet

**HTML/CSS/JS autonome, sans étape de build.** Un seul fichier `index.html` qui
embarque son style et sa logique. Pas de bundler, pas de framework, pas de
`npm install` — nginx sert le fichier tel quel (déploiement Coolify).

**N'introduis jamais d'étape de compilation** — ça casserait la publication.

| Chemin | Rôle |
|---|---|
| `index.html` | L'application entière (interface + logique) |
| `sql/001_schema.sql` | Schéma de la base (migration appliquée manuellement) |
| `supabase/functions/admin-create-user/` | Edge function de création de comptes |

## Backend

Base Supabase **dédiée** : `yaznxsvklzsdnlykbsht`. Elle est **volontairement
distincte** de la base du portail interne — ne mélange jamais les deux.

- **Clé publishable uniquement** dans le HTML. Jamais de clé `service_role` :
  elle serait lisible par tout le monde. C'est la RLS qui protège les données.
- Les fichiers de `sql/` sont des migrations **appliquées à la main**. Ne
  suppose **jamais** qu'un fichier a été exécuté : vérifie l'état réel des
  tables avant de construire dessus.

## Conventions

- Français partout : interface, commentaires, messages de commit.
- Dates `JJ/MM/AAAA`, montants `1 234,56 €`.
- Les montants suivent les règles comptables du cabinet : vérifie toujours avec
  David si un montant est HT ou TTC avant de coder un calcul.

## Publication

```bash
git pull            # TOUJOURS avant d'éditer
# ... modifications ...
git add <fichiers>  # ciblé, pas de "git add ." aveugle
git commit -m "message en français"
git push
```

---

# Règles de travail — à respecter à chaque intervention

**Règle d'or : tu travailles UNIQUEMENT sur ce projet.** Tu ne touches à aucun
autre dossier ni à aucun autre logiciel de David, même si tu penses que ce
serait utile. Si le besoin déborde sur un autre projet, dis-le et arrête-toi.

## Autonomie maximale

**Tout ce que tu es capable de faire toi-même, fais-le, sans me le demander.**
Ne me demande pas de faire des choses que tu peux faire seul, et ne me demande
pas la permission pour des actions courantes et réversibles. Réserve tes
questions à **deux cas seulement** :

- **(a)** ce que **moi seul** peux faire (créer un compte, effectuer un
  paiement, obtenir une clé API, cliquer dans un service externe, faire un
  choix business) ;
- **(b)** les **validations déjà prévues dans ces règles** (proposer un plan
  avant une tâche non triviale, et ne rien supprimer / déployer / publier sans
  mon accord).

En dehors de ces deux cas, **agis directement au lieu de me demander**.

## Je suis débutant : explique-moi pas à pas

Quand il y a quelque chose que **je** dois faire moi-même, pars toujours du
principe que je suis **DÉBUTANT et non technique**. Explique-moi chaque étape,
dans l'ordre, très précisément, **sans jargon**. Donne-moi le maximum de
**liens directs** et dis-moi exactement où cliquer (« va sur ce lien, clique
ici, puis là »). Ne suppose jamais que je sais faire une manipulation
technique. Si je dois copier, choisir ou coller quelque chose, montre-moi
exactement **quoi** et **où**.

## Avant toute modification

- **Explore et comprends** le code concerné avant d'agir. Ne te base jamais sur
  une supposition : va vérifier dans le code réel.
- **Respecte la techno déjà en place** (langage, framework, base de données,
  gestionnaire de paquets). N'introduis **aucune** nouvelle technologie ni
  librairie sans demander d'abord.
- **S'il te manque une information** (un chemin, une intention, un nom), pose la
  question à David. **Ne devine pas.**

## Méthode obligatoire

- **Un seul objectif à la fois**, par **petites étapes vérifiables**.
- Pour toute tâche non triviale : **propose d'abord un plan**, attends la
  validation de David, **ensuite seulement tu codes**.
- **Teste après chaque étape** et dis précisément **comment vérifier** le
  résultat.

## Interdits (sauf accord explicite de David)

- Ne **supprime**, ne **renomme**, n'**écrase** aucun fichier sans demander.
- Ne **réécris pas** de grandes portions de code qui fonctionnent déjà.
- Ne crée **pas de doublon** : vérifie si la chose existe déjà et réutilise-la.
- Ne modifie **que ce qui est strictement nécessaire** à la demande. Ne touche à
  rien en dehors du périmètre demandé.
- Ne change **pas** la configuration, les variables d'environnement, les ports
  ni la base de données sans prévenir et expliquer pourquoi.

## Sécurité et sauvegarde

- Avant un changement important, assure-toi que l'état actuel est **bien
  sauvegardé sur git** (commit), pour qu'on puisse revenir en arrière.
- Ne **déploie / ne publie rien** sans l'accord de David.
- Ne touche pas aux **secrets et clés** (fichiers `.env`), et ne les affiche
  jamais.

## En cas de problème

- Si quelque chose casse, **explique la cause réelle** dans le code, ne la
  contourne pas, **corrige proprement**. Assume l'erreur au lieu de la rejeter.

## À la fin de chaque intervention

- Fais un **récapitulatif simple** : ce que tu as changé, dans quels fichiers,
  pourquoi, comment le tester, et ce qu'il reste à faire.

## Exécution des tâches techniques — David n'est pas technique

David ne sait pas / ne peut pas utiliser le terminal (Git Bash, commandes SQL, ouverture de fichiers de préviz).

**RÈGLE :** si une étape peut être exécutée par TOI (Claude Code) — exécuter un `.sql` sur le serveur, lancer une commande, un `git`, un build, générer un aperçu — tu la **FAIS toi-même**. Tu ne demandes **JAMAIS** à David de taper quoi que ce soit dans un terminal.

**Sécurité conservée :** avant une modification de base ou une publication, tu expliques et tu attends son « go » ; après un `.sql`, tu **VÉRIFIES** qu'il est appliqué et tu le confirmes simplement ; tu ne publies rien sans son accord.

**David décide (oui/non), TOI tu exécutes.**
