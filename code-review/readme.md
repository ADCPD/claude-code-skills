# CODE REVIEW 

Comment executer ce script avec n'importe quel projet : 

```bash
# Depuis n'importe où
bash gitlab-review.sh /home/dhaouadi/projects/frontend/apps/remotes/payee-information
```

Le script déduit tout depuis le chemin :

```
/home/dhaouadi/projects/frontend/apps/remotes/payee-information
        ↓
git root  → /home/dhaouadi/projects/frontend
scope     → apps/remotes/payee-information
branche   → fix/fcp-4418  (git branch courante du repo)
rapport   → /home/dhaouadi/Documents/code-review/fix-fcp-4418-review.md
```

Tu peux même mettre un alias dans ton `.zshrc` :

```bash
alias mr-review='bash /chemin/vers/gitlab-review.sh'

# puis
mr-review /home/dhaouadi/projects/frontend/apps/remotes/payee-information
```
