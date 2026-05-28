
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
