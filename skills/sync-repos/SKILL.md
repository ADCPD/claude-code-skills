# Sync Repositories

Synchronise les repositories explicitement demandés par l'utilisateur.

## Rules

- Ne jamais modifier les fichiers métier.
- Ne jamais créer de commit.
- Ne jamais créer de branche.
- Ne jamais faire de push.
- Ne jamais utiliser `git reset --hard`.
- Ne jamais supprimer de modifications locales.
- Vérifier l'état du repository avant toute synchronisation.
- Si le repository contient des modifications locales, le signaler et ne pas le synchroniser automatiquement.
- Utiliser `git fetch --prune`.
- Synchroniser uniquement la branche demandée.
- Vérifier le résultat après synchronisation.

## Workflow

Pour chaque repository :

1. Vérifier que le repository existe.
2. Vérifier la branche courante.
3. Vérifier `git status --short`.
4. Si le workspace est dirty :
   - ne pas modifier le repository ;
   - reporter le repository comme `SKIPPED`.
5. Exécuter `git fetch --prune`.
6. Vérifier la branche distante.
7. Mettre à jour la branche avec fast-forward uniquement.
8. Vérifier le nouveau commit HEAD.
9. Produire un résumé.

## Output

Retourner :

| Repository | Branch | Status | Before | After |
|------------|--------|--------|--------|-------|

Statuses possibles :

- UPDATED
- UP_TO_DATE
- SKIPPED_DIRTY
- FAILED
