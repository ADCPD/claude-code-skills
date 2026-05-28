# CODE REVIEW SCRIPT - LOCAL LINUX ENV

Copier le script dans la racine de votre projet : 


```bash
> bash -l gitlab-review.sh

╔══════════════════════════════════════╗
║   GitLab MR Review — Claude Code     ║
╚══════════════════════════════════════╝

Branche initiale : fix/fcp-4418
Rapport    : /home/dhaouadi/Documents/code-review/fix-fcp-4418-review.md

⬇ Switch sur main + pull...
✓ main à jour
↩ Retour sur fix/fcp-4418...
✓ De retour sur fix/fcp-4418

📂 Diff main ↔ fix/fcp-4418 — apps/remotes/payee-information
Stats :  .../bank-account-edit/BankAccountEditView.test.tsx |  81 ++++++-
 .../bank-account-edit/BankAccountEditView.tsx      |  39 ++--
 .../src/widgets/country/useCountriesQuery.test.tsx | 257 +++++++--------------
 .../src/widgets/country/useCountriesQuery.ts       |  32 +--
 4 files changed, 203 insertions(+), 206 deletions(-)

🧠 Analyse Claude en cours...

✅ Rapport généré !
📄 /home/dhaouadi/Documents/code-review/fix-fcp-4418-review.md

🎯 Score    : 7/10
gitlab-review.sh: ligne 259: [[: 0
0 : erreur de syntaxe dans l'expression (le symbole erroné est « 0 »)
🟢 CRITICAL : aucune

```

Le rapport sera generé dans le dossier : 

```bash
/home/dhaouadi/Documents/code-review
```

En attendant, vérifie aussi rapidement :

```bash
# Claude est bien installé et accessible ?
which claude
claude --version

# Le dossier Downloads existe ?
ls ~/home/dhaouadi/Documents/code-review

# Test manuel de claude -p
echo "dis bonjour" | claude -p --output-format text
```
