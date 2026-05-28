#!/usr/bin/env bash
# ============================================================
# gitlab-review.sh
# Usage: bash gitlab-review.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="apps/remotes/payee-information"
BASE_BRANCH="main"

# ─── Dépendances ────────────────────────────────────────────
check_deps() {
  for cmd in git claude; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}✗ '$cmd' non trouvé${NC}"
      exit 1
    fi
  done
}

# ─── Output path ────────────────────────────────────────────
get_output_path() {
  local branch="$1"
  local current_user safe_branch output_dir
  current_user=$(whoami)
  safe_branch=$(echo "$branch" | tr '/' '-' | tr ' ' '-')

  if [[ -d "/home/${current_user}" ]]; then
    output_dir="/home/${current_user}/Documents/code-review"
  else
    output_dir="$HOME/Documents/code-review"
  fi

  mkdir -p "$output_dir"
  echo "${output_dir}/${safe_branch}-review.md"
}

# ─── Crée un rapport minimal si rien à signaler ─────────────
write_empty_report() {
  local output_path="$1" branch="$2" reason="$3"
  cat > "$output_path" << EOF
# Code Review — \`${branch}\`

> **Scope :** \`${TARGET_DIR}\`
> **Comparé à :** \`${BASE_BRANCH}\`
> **Date :** $(date '+%d/%m/%Y %H:%M')

---

## 📊 Résumé

| Score global | CRITICAL | WARNING | INFO | GOOD |
|---|---|---|---|---|
| N/A | 0 | 0 | 0 | 0 |

> ${reason}

---

*Review générée par Claude — $(date '+%d/%m/%Y %H:%M')*
EOF
}

# ─── Main ────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════╗"
  echo "║   GitLab MR Review — Claude Code     ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${NC}"

  check_deps

  # Vérif repo git
  git rev-parse --git-dir &>/dev/null || {
    echo -e "${RED}✗ Pas dans un repo git${NC}"; exit 1
  }

  # 1. Branche initiale
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  echo -e "${BOLD}Branche initiale :${NC} ${GREEN}${current_branch}${NC}"

  if [[ "$current_branch" == "$BASE_BRANCH" ]]; then
    echo -e "${RED}✗ Tu es sur main — checkout ta feature branch d'abord${NC}"
    exit 1
  fi

  # 2. Output path (calculé tôt pour garantir l'écriture)
  local output_path
  output_path=$(get_output_path "$current_branch")
  echo -e "${BOLD}Rapport    :${NC} ${CYAN}${output_path}${NC}"
  echo ""

  # 3. Switch main + pull
  echo -e "${CYAN}⬇ Switch sur ${BASE_BRANCH} + pull...${NC}"
  git switch "$BASE_BRANCH" --quiet
  git pull origin "$BASE_BRANCH" --quiet 2>&1 | tail -1
  echo -e "${GREEN}✓ ${BASE_BRANCH} à jour${NC}"

  # 4. Retour branche initiale
  echo -e "${CYAN}↩ Retour sur ${current_branch}...${NC}"
  git switch "$current_branch" --quiet
  echo -e "${GREEN}✓ De retour sur ${current_branch}${NC}"
  echo ""

  # 5. Calcul du diff
  echo -e "${BOLD}📂 Diff ${BASE_BRANCH} ↔ ${current_branch} — ${TARGET_DIR}${NC}"

  local diff_content diff_stat commits

  # Vérifie si le dossier existe dans la branche
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${YELLOW}⚠ Dossier '${TARGET_DIR}' non trouvé dans cette branche${NC}"
    write_empty_report "$output_path" "$current_branch" \
      "Le dossier \`${TARGET_DIR}\` n'existe pas dans la branche \`${current_branch}\`."
    echo -e "${GREEN}✅ Rapport créé (dossier absent) : ${output_path}${NC}"
    exit 0
  fi

  diff_stat=$(git diff "${BASE_BRANCH}...${current_branch}" --stat -- "$TARGET_DIR" 2>/dev/null || true)
  diff_content=$(git diff "${BASE_BRANCH}...${current_branch}" -- "$TARGET_DIR" 2>/dev/null || true)
  commits=$(git log "${BASE_BRANCH}..${current_branch}" --oneline --no-merges -- "$TARGET_DIR" 2>/dev/null || true)

  echo "Stats : ${diff_stat:-"(aucun changement)"}"
  echo ""

  # 6. Si diff vide → rapport "rien à signaler"
  if [[ -z "$diff_content" ]]; then
    echo -e "${YELLOW}⚠ Aucune différence détectée dans ${TARGET_DIR}${NC}"
    write_empty_report "$output_path" "$current_branch" \
      "Aucune modification détectée dans \`${TARGET_DIR}\` entre \`${BASE_BRANCH}\` et \`${current_branch}\`. Rien à signaler."
    echo -e "${GREEN}✅ Rapport créé (rien à signaler) : ${output_path}${NC}"
    exit 0
  fi

  # 7. Prompt Claude
  local prompt
  prompt=$(cat <<EOF
Tu es un expert code reviewer senior (PHP/Symfony, TypeScript/React, bonnes pratiques).

Effectue une code review complète des changements suivants.

## Contexte
- Branche reviewée : \`${current_branch}\`
- Comparé à : \`${BASE_BRANCH}\`
- Scope : \`${TARGET_DIR}\`
- Date : $(date '+%d/%m/%Y %H:%M')

## Commits
${commits:-"(aucun commit spécifique au scope)"}

## Statistiques
${diff_stat}

## Diff complet
\`\`\`diff
${diff_content:0:20000}
\`\`\`

---

Génère un rapport Markdown avec EXACTEMENT cette structure :

# Code Review — \`${current_branch}\`

> **Scope :** \`${TARGET_DIR}\`
> **Comparé à :** \`${BASE_BRANCH}\`
> **Date :** $(date '+%d/%m/%Y')

---

## 📊 Résumé

| Score global | CRITICAL | WARNING | INFO | GOOD |
|---|---|---|---|---|
| X/10 | N | N | N | N |

> Une phrase résumant la qualité globale.

---

## 🔴 Erreurs CRITIQUES (bloquent le merge)

### CRITICAL-N — Titre court
**Fichier :** \`path/to/file.ts:LINE\`
**Problème :** description claire
**Fix :**
\`\`\`typescript
// code corrigé
\`\`\`

---

## 🟠 Avertissements

### WARNING-N — Titre court
**Fichier :** \`path/to/file.ts:LINE\`
**Problème :** description
**Suggestion :** fix recommandé

---

## 🟡 Points d'amélioration

- \`fichier\` — description courte

---

## 🟢 Bonnes pratiques observées

- ✅ point positif

---

## 💡 Recommandations globales

1. recommandation

---
*Review générée par Claude — $(date '+%d/%m/%Y %H:%M')*
EOF
)

  # 8. Lance Claude avec fallback garanti
  echo -e "${BOLD}🧠 Analyse Claude en cours...${NC}"

  local claude_output claude_exit=0
  claude_output=$(echo "$prompt" | claude -p --output-format text 2>/tmp/claude-err.log) || claude_exit=$?

  if [[ $claude_exit -ne 0 ]] || [[ -z "$claude_output" ]]; then
    echo -e "${YELLOW}⚠ Claude n'a pas répondu (exit: ${claude_exit})${NC}"
    [[ -s /tmp/claude-err.log ]] && echo "  Erreur : $(cat /tmp/claude-err.log)"
    write_empty_report "$output_path" "$current_branch" \
      "Claude n'a pas pu générer la review (erreur CLI). Lance \`claude --version\` pour vérifier l'installation."
  else
    echo "$claude_output" > "$output_path"
  fi

  # 9. Résumé final
  echo ""
  echo -e "${GREEN}${BOLD}✅ Rapport généré !${NC}"
  echo -e "📄 ${CYAN}${output_path}${NC}"
  echo ""

  local score critical_count
  score=$(grep -oP '\d+/10' "$output_path" 2>/dev/null | head -1 || echo "N/A")
  critical_count=$(grep -c "^### CRITICAL" "$output_path" 2>/dev/null || echo "0")

  echo -e "🎯 Score    : ${BOLD}${score}${NC}"
  if [[ "$critical_count" -gt 0 ]]; then
    echo -e "${RED}🔴 CRITICAL : ${critical_count} erreur(s) à corriger${NC}"
  else
    echo -e "${GREEN}🟢 CRITICAL : aucune${NC}"
  fi
}

main "$@"
