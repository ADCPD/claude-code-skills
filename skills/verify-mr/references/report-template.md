# Report template

Skeleton for `~/projects/<jira-key>-review-mr-<N>.md`.

**Write the report in the language of the JIRA ticket.** The template below is in French
because Believe FCP tickets are French; translate the headings if the ticket is English.

Placeholders are in `<angle brackets>`. Drop any section that has nothing to say — an empty
section is noise. Never keep a heading with "N/A" under it.

---

````markdown
# Review MR !<N> — <JIRA-KEY> : <titre court du ticket>

| | |
| --- | --- |
| **MR** | [!<N>](<url>) — `<branche source>` |
| **Ticket** | [<JIRA-KEY>](<url>) — *<statut>* |
| **Auteur** | <auteur> |
| **Base** | `<base>` (`<sha>`) — **<mergée / non mergée>** |
| **Diff** | <X> fichiers, +<A> / −<S> |
| **Date review** | <YYYY-MM-DD> |
| **Verdict** | <✅ Approuvable / ⚠️ Approuvable après correction du point 🔴 #N / ❌ À revoir> |
| **Score** | **<N> / 10** |

---

## 1. Résumé exécutif

<Trois à cinq phrases. Ce que fait la MR, si elle répond au ticket, et LE point qui
décide du merge. Un relecteur pressé doit pouvoir s'arrêter ici.>

### Portes qualité (exécutées sur la branche MR)

| Contrôle | Commande | Résultat |
| --- | --- | --- |
| Tests unitaires ciblés | `<commande exacte>` | ✅ **OK — <N> tests, <M> assertions** |
| Analyse statique | `<commande exacte>` | ✅ **No errors** |
| Code style | `<commande exacte>` | <✅ OK / ⚠️ N fichiers — **aucun n'appartient à cette MR** (préexistants sur `<base>`)> |

---

## 2. Conformité au ticket

| # | Exigence <JIRA-KEY> | Statut | Vérification |
| --- | --- | --- | --- |
| 1 | <critère d'acceptation, repris mot pour mot> | ✅ | `<fichier:ligne>` ou `<nom du test>` |
| … | <décision PO prise en commentaire> | ✅ | … |
| … | <élément déclaré hors périmètre> | ⚠️ | **Non respecté** — voir 🟡 #N |

<Une phrase de conclusion : la règle de gestion centrale est-elle implémentée ?>

---

## 3. Constats

### 🔴 #1 — <titre : le symptôme, pas la cause>

**Fichier :** `<chemin>`
**Lignes :** <plage>

<Ce qui a changé et pourquoi c'est faux. Expliquer le mécanisme, pas seulement le symptôme.>

**Reproduction** (exécutée sur la branche MR) :

```php
<le code réellement lancé>
```

| | <ce qui est produit> |
| --- | --- |
| Attendu | `<valeur>` |
| **Obtenu** | **`<valeur réelle, copiée depuis stdout>`** |

<Impact métier : qui consomme cette valeur et que voit-il ?>

**<Preuve que c'est un oubli, pas un choix — si une branche jumelle traite le cas :>**

```php
<extrait de la branche jumelle>
```

**Correctif proposé :**

```php
<le patch, prêt à coller>
```

**Test à ajouter :**

```php
public function test<NomExplicite>(): void
```

### 🟠 #2 — <titre>

<Même structure. Pour un point à arbitrer, terminer par une **Action** nommant la personne
qui doit trancher.>

### 🟡 #3 — <titre>

<Traçabilité, scope creep, risque de conflit, divergence de convention. Plus court.>

---

## 4. Améliorations proposées (non bloquantes)

### A. <titre>

<Le quoi, le pourquoi, et un extrait de code si ça aide. Numéroter en lettres pour
distinguer des constats.>

---

## 5. Points positifs

<Section obligatoire, jamais vide. Liste à puces de ce qui est réellement bien fait :
couverture de test, qualité des docblocks, hygiène des commits, invariants respectés,
correction d'une dette préexistante. Être spécifique — « bon code » ne sert à personne.>

---

## 6. Checklist avant merge

- [ ] 🔴 **Corriger #1** — <action en une ligne>
- [ ] 🟠 **Trancher #2** — <question, et qui répond>
- [ ] 🟡 **Documenter #3** — <action>
- [ ] ℹ️ <suivi optionnel>

---

## Annexe — méthode de vérification

```bash
<toutes les commandes réellement lancées, dans l'ordre, avec leur résultat en commentaire>
```

<Une phrase précisant comment les constats ont été prouvés — et qu'il s'agit de sorties
réelles, pas d'inférences de lecture.>

> Branches locales créées pour cette review : `mr-<N>`. À supprimer avec
> `git branch -D mr-<N>` si elles ne servent plus.
````

---

## Rédaction

- **Une affirmation = une preuve.** Pas de commande lancée, pas de constat — ou alors
  étiqueté « non vérifié » explicitement.
- **Citer les sorties réelles**, jamais des valeurs plausibles reconstituées de mémoire.
- **Sévérité honnête.** Un 🔴 reproductible pèse plus que huit 🟡 spéculatifs.
- **Viser le code, pas la personne.** « la garde filtre les groupes au lieu des lignes »,
  pas « l'auteur a oublié ».
- **Un correctif collable** pour chaque constat, sinon ce n'est pas actionnable.
- **Distinguer défaut / décision à prendre.** Un comportement que le ticket ne couvre pas
  n'est pas un bug : c'est une question pour le PO, et il faut nommer la personne.

## Nommage du fichier

`~/projects/<jira-key-en-minuscules>-review-mr-<N>.md` — par exemple
`~/projects/fcp-4577-review-mr-276.md`.

Ça s'aligne sur les notes existantes du dossier (`fcp-4493-investigation.md`,
`fcp-4586-investigation.md`) et reste triable par ticket.
