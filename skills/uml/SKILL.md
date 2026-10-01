---
name: uml
description: >
  Génère et maintient des diagrammes UML (classes, séquence, composants, domaine,
  ERD, états) en Mermaid à partir du code réel, versionnés dans docs/architecture/.
  Source de vérité prioritaire : le graphe graphify du repo (graphify query / explain /
  path) ; sinon lecture ciblée du code ; sinon contexte de session. Ne modifie jamais
  le code source. Use for "/uml", "diagramme UML", "diagramme de classes",
  "diagramme de séquence", "schéma d'architecture", "class diagram", "sequence diagram",
  "component diagram", "modélise le domaine", "documente l'architecture".
trigger: /uml
---

# /uml

Produire des diagrammes UML **fidèles au code existant**, en Mermaid, versionnables dans Git.

## Usage

```
/uml                                  # overview : composants + classes du domaine principal
/uml classes [<scope>]                # diagramme de classes (scope = dossier, bounded context, module)
/uml sequence <use case>              # séquence d'un cas d'usage (ex: "création d'un payment")
/uml components [<scope>]             # architecture / dépendances entre couches et services
/uml domain <AggregateOrEntity>       # modèle de domaine autour d'un agrégat
/uml erd [<scope>]                    # entity-relationship (entités Doctrine / schéma SQL)
/uml state <Entity>                   # machine à états d'une entité (status, workflow)
/uml refresh                          # régénère les diagrammes existants de docs/architecture/
/uml --out <dir>                      # dossier de sortie (défaut: docs/architecture/)
/uml --repo <path>                    # repo cible (défaut: cwd)
```

`/uml --help` → imprimer le bloc Usage ci-dessus et s'arrêter.

## Périmètre

Ce skill fait de l'**UML structurel et comportemental** (classes, séquence, composants, domaine, ERD, états).
Pour un flow métier / user journey / flowchart produit, utiliser le skill `flow-diagram` (blv-fcp) : ne pas dupliquer.

## Règles non négociables

1. **Ne jamais inventer** une classe, une méthode, une relation ou une dépendance. Tout élément du diagramme doit être traçable à un fichier réel.
2. **Ne jamais modifier le code source.** Le skill n'écrit que dans le dossier de sortie.
3. Tout élément **déduit** (non prouvé par lecture directe : edge `INFERRED` de graphify, convention implicite) va dans la section `Hypothèses` du fichier, jamais silencieusement dans le diagramme. S'il est dans le diagramme, le marquer (`..>` + note, ou stéréotype `<<inferred>>`).
4. **Lisibilité > exhaustivité** : plusieurs diagrammes ciblés plutôt qu'un diagramme géant. Seuil dur : **25 nœuds max** par diagramme ; au-delà, découper par couche ou par bounded context et lier les fichiers entre eux.
5. Identifier explicitement les **interfaces** (`<<interface>>`), les **abstract** (`<<abstract>>`), les **value objects** (`<<value object>>`), les **enums** (`<<enumeration>>`).
6. Ne représenter getters/setters triviaux **jamais**. Uniquement les méthodes porteuses de comportement métier.
7. Respecter la nature du projet (voir `## Adaptation au type de projet`). Ne pas plaquer un vocabulaire DDD/hexagonal sur un projet qui n'en est pas un.

## Étape 1 — Résoudre le contexte

```bash
REPO="${REPO:-$(pwd)}"
OUT="${OUT:-$REPO/docs/architecture}"
```

Déterminer le **type de projet** avant toute analyse :

| Signal | Type | Conséquence |
|---|---|---|
| `composer.json` avec `symfony/framework-bundle`, dossier `src/` + `config/services.yaml` | Symfony moderne | UML complet, couches Domain/Application/Infrastructure si elles existent réellement |
| `package.json` avec `react` | Frontend React | Pas de diagramme de classes : composants, hooks, stores, props. Utiliser `components` / `sequence` |
| PHP natif sans autoloader PSR-4 moderne, includes/requires, repos `static` / `producer` / `framework` / `believe-core` | Legacy natif | Vocabulaire du code existant, pas de DDD plaqué. Diagrammes descriptifs (fichiers, fonctions, tables), pas normatifs |
| Autre | Générique | Rester sur ce que le code montre |

Ne jamais qualifier une architecture d'« hexagonale » ou « DDD » si les dossiers/interfaces ne le prouvent pas.

## Étape 2 — Collecter la vérité (ordre strict)

### 2.1 graphify d'abord (si disponible)

```bash
test -f "$REPO/graphify-out/graph.json" && echo GRAPH_OK
```

Si le graphe existe, il est la source primaire — il coûte moins de tokens que le grep brut et porte déjà les relations :

```bash
graphify query "classes, interfaces et relations du domaine <scope>"
graphify explain "<ClassName>"                 # voisinage direct d'un nœud
graphify path "<Controller>" "<Repository>"    # chaîne d'appel entre deux points
```

- Pour une **séquence**, `graphify path "<EntryPoint>" "<Sink>"` donne l'ossature des participants ; compléter l'ordre des appels par lecture ciblée des méthodes concernées.
- Si `graphify-out/wiki/index.md` existe, l'utiliser pour la navigation large avant de descendre dans les fichiers.
- Le graphe peut être périmé : vérifier chaque classe retenue par un `Read`/`sed -n` du fichier réel avant de la mettre dans le diagramme. Un nœud graphify n'est pas une preuve suffisante pour une signature de méthode.
- Graphe absent : **ne pas le construire sans demander** (coût LLM). Proposer `/graphify <path>` en une ligne, et continuer en 2.2.

### 2.2 Lecture ciblée du code (fallback ou complément)

Par type de diagramme :

- **classes / domain** : entités et VO (`src/**/Entity`, `src/**/Domain`, attributs `#[ORM\Entity]`), interfaces de repository, services du domaine, handlers.
- **sequence** : point d'entrée (Controller, Command, Consumer, EventSubscriber) → suivre les appels réels méthode par méthode jusqu'au sink (DB, HTTP externe, bus, log).
- **components** : `config/services.yaml`, namespaces de premier niveau, clients HTTP externes, `messenger.yaml`, dépendances `composer.json` structurantes.
- **erd** : mappings Doctrine (`#[ORM\ManyToOne]`, `JoinTable`), ou migrations / schéma SQL si pas d'ORM.
- **state** : enums de statut, transitions (`workflow.yaml` Symfony, `setStatus()`, guards, constantes `STATUS_*`).

### 2.3 Contexte de session

Ce que l'utilisateur vient de décrire (ticket, MR en cours) complète le cadrage du scope, **jamais** le contenu du diagramme.

## Étape 3 — Générer le Mermaid

Templates et pièges de syntaxe : voir `references/mermaid-patterns.md`. Le lire avant d'écrire le premier diagramme.

Contrôles avant écriture :
- Chaque nœud est rattaché à un fichier existant.
- Aucune flèche sans direction de dépendance vérifiée (qui appelle qui, pas « qui est proche de qui »).
- ≤ 25 nœuds. Sinon découper.
- Les noms sont ceux du code (FQCN raccourci au nom court, namespace en note si ambigu).

Validation syntaxique si l'outil est présent, sinon relecture manuelle :

```bash
command -v mmdc >/dev/null && mmdc -i "$FILE" -o /tmp/uml-check.svg >/dev/null 2>&1 && echo MERMAID_OK
```

## Étape 4 — Écrire la sortie

Un fichier par diagramme, dans `$OUT` :

```
docs/architecture/
├── README.md              # index : liste des diagrammes, date, comment régénérer
├── components.md
├── class-diagram-<scope>.md
├── sequence-<use-case>.md
├── domain-<aggregate>.md
├── erd.md
└── state-<entity>.md
```

Gabarit obligatoire de chaque fichier :

~~~markdown
# <Titre>

<2–4 lignes : ce que le diagramme montre, et ce qu'il ne montre pas.>

## Diagramme

```mermaid
<le diagramme>
```

## Sources

- `src/Domain/Payment/Payment.php`
- `src/Application/Handler/CreatePaymentHandler.php`

## Hypothèses

- <déduction non prouvée, ou "Aucune">

---
Généré le <YYYY-MM-DD> — scope : `<scope>` — source : graphify | lecture code
~~~

Date : `date +%F`. `README.md` est mis à jour (ou créé) à chaque run avec la liste des diagrammes et leur date.

`/uml refresh` : relire chaque fichier existant de `$OUT`, en reprendre le scope, régénérer, et **signaler explicitement les écarts** entre l'ancien et le nouveau diagramme (classe disparue, relation ajoutée) — c'est le vrai signal de dérive architecturale.

Après écriture, si le repo a un graphe : `graphify update .` n'est pas nécessaire (aucun code modifié). Ne pas le lancer.

## Étape 5 — Restituer

Réponse courte :
- fichiers créés/mis à jour (chemins cliquables),
- 1 ligne par diagramme sur ce qu'il révèle,
- section **Écarts constatés** si le code contredit l'architecture supposée (dépendance Domain → Infrastructure, entité anémique, repository concret injecté à la place de l'interface, cycle entre modules). Signaler, ne pas corriger.

Ne pas coller l'intégralité des diagrammes dans la réponse : ils sont dans les fichiers.

## Adaptation au type de projet

**Symfony moderne** — séparer visuellement Domain / Application / Infrastructure **seulement si les dossiers existent**. Marquer les interfaces de repository dans le Domain et leurs implémentations Doctrine dans l'Infrastructure. Signaler toute flèche Domain → Infrastructure comme violation.

**Legacy natif (static, producer, framework, believe-core)** — pas de couches inventées. Diagramme de composants au niveau fichiers/modules et tables, séquence au niveau des fonctions réellement appelées. Aucune recommandation de refonte non demandée.

**Frontend React** — `classDiagram` est inadapté. Utiliser `flowchart` pour l'arbre de composants (props descendantes, callbacks remontants) et `sequenceDiagram` pour un flux user → composant → hook → API. Typer les props d'après le TS réel.

**Squad FCP / code financier** — sur un diagramme de domaine ou d'ERD touchant à de la monnaie, faire apparaître explicitement le type porteur du montant et de la devise (`Money`, `amount` + `currency`, `int` en centimes…). Si le montant est un `float` ou un scalaire sans devise associée, le signaler dans **Écarts constatés**.
