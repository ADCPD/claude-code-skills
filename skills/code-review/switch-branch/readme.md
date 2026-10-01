# CODE REVIEW - WITH SWITCH BRANCH

```bash
# Contre main (défaut)
bash gitlab-review.sh /home/dhaouadi/projects/frontend/apps/remotes/payee-information

# Contre main (explicite)
bash gitlab-review.sh /home/dhaouadi/projects/frontend/apps/remotes/payee-information main

# Contre develop
bash gitlab-review.sh /home/dhaouadi/projects/frontend/apps/remotes/payee-information develop

# Contre une release branch
bash gitlab-review.sh /home/dhaouadi/projects/frontend/apps/remotes/payee-information release/2.0
```

Tu peux même mettre un alias dans ton .zshrc :

```bash
alias mr-review='bash /chemin/vers/gitlab-review.sh'

# puis 

# 1. default (main)
mr-review /home/dhaouadi/projects/frontend/apps/remotes/payee-information  

# 2. use (develop)
mr-review /home/dhaouadi/projects/frontend/apps/remotes/payee-information develop
```
