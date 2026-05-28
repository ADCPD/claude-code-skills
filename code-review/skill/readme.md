
## Ce que fait ce skill vs le script standalone

| | Script bash | Skill Claude Code |
|---|---|---|
| Déclenchement | `bash gitlab-review.sh <path>` | Phrase naturelle en chat |
| Logique | Dans le `.sh` | Claude exécute le script via `bash_tool` |
| Rapport | Écrit par le script | Écrit par le script + `present_files` |
| Extensible | Modifier le `.sh` | Modifier le `SKILL.md` |

---

## Installation dans Claude Code

```bash
# Glisser le .skill dans Claude Code
# Settings → Skills → Install from file → gitlab-mr-review.skill
```

## Utilisation après installation

```
"review ma branche apps/remotes/payee-information contre develop"
"génère un rapport de code review pour /home/dhaouadi/projects/frontend/apps/remotes/payee-information"
"analyse mon diff avant merge"
```

Claude détecte l'intention, collecte le chemin et la branche, exécute le script et te présente le rapport directement dans le chat.

---

## Axes de review

| Axe | Couleur | Ce qui est analysé |
|---|---|---|
| **CRITICAL** | 🔴 | Sécurité, injections, async non géré |
| **SOLID** | 🟣 | SRP, OCP, LSP, ISP, DIP — avec refactoring suggéré |
| **KISS** | 🔵 | Complexité inutile, abstraction prématurée, imbrication > 3 niveaux |
| **TDD** | 🟡 | Tests manquants, happy path only, assertions trop larges, cas limites |
| **Clean Code** | 🟠 | Nommage, duplication, couplage, props drilling, UI/logique mélangés |
| **Bonnes pratiques** | 🟢 | Ce qui est bien fait |

---

Le résumé en fin de rapport affiche maintenant un compteur par axe :

```
🎯 Score  : 7/10
🔴 CRITICAL : 1  🟣 SOLID : 2  🔵 KISS : 1  🟡 TDD : 3
```
