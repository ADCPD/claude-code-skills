#!/usr/bin/env bash
# ============================================================
# gitlab-review.sh <path_to_scope>
#
# Usage :
#   bash gitlab-review.sh /home/dhaouadi/projects/frontend/apps/remotes/payee-information
#
# Le script déduit :
#   - la racine du repo git depuis le chemin fourni
#   - le scope relatif (TARGET_DIR)
#   - la branche courante
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

BASE_BRANCH="main"

# ─── Dépendances ────────────────────────────────────────────
check_deps() {
  for cmd in git claude; do
    command -v "$cmd" &>/dev/null || {
      echo -e "${RED}✗ '$cmd' non trouvé${NC}"; exit 1
    }
  done
}

# ─── Output path ────────────────────────────────────────────
get_output_path() {
  local branch="$1"
  local safe_branch current_user output_dir
  safe_branch=$(echo "$branch" | tr '/' '-' | tr ' ' '-')
  current_user=$(whoami)

  if [[ -d "/home/${current_user}" ]]; then
    output_dir="/home/${current_user}/Documents/code-review"
  else
    output_dir="$HOME/Documents/code-review"
  fi

  mkdir -p "$output_dir"
  echo "${output_dir}/${safe_branch}-review.md"
}

# ─── Rapport minimal garanti ────────────────────────────────
write_empty_report() {
  local output_path="$1" branch="$2" target_dir="$3" reason="$4"
  cat > "$output_path" << EOF
# Code Review — \`${branch}\`

> **Scope :** \`${target_dir}\`
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

  # ── 1. Argument : chemin vers le scope ──────────────────
  local input_path
  if [[ $# -gt 0 ]]; then
    input_path=$(realpath "$1")
  else
    echo -e "${RED}✗ Chemin requis en argument${NC}"
    echo "  Usage : bash gitlab-review.sh /chemin/vers/mon/dossier"
    exit 1
  fi

  if [[ ! -d "$input_path" ]]; then
    echo -e "${RED}✗ Chemin non trouvé : ${input_path}${NC}"
    exit 1
  fi

  # ── 2. Déduit la racine git depuis le chemin ────────────
  local git_root
  git_root=$(git -C "$input_path" rev-parse --show-toplevel 2>/dev/null) || {
    echo -e "${RED}✗ '${input_path}' n'est pas dans un repo git${NC}"
    exit 1
  }

  # ── 3. Scope relatif à la racine du repo ────────────────
  local target_dir
  target_dir=$(realpath --relative-to="$git_root" "$input_path")

  # ── 4. Branche courante ─────────────────────────────────
  local current_branch
  current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD)

  # ── 5. Output path ──────────────────────────────────────
  local output_path
  output_path=$(get_output_path "$current_branch")

  echo -e "${BOLD}Repo       :${NC} ${git_root}"
  echo -e "${BOLD}Scope      :${NC} ${CYAN}${target_dir}${NC}"
  echo -e "${BOLD}Branche    :${NC} ${GREEN}${current_branch}${NC}"
  echo -e "${BOLD}Rapport    :${NC} ${CYAN}${output_path}${NC}"
  echo ""

  if [[ "$current_branch" == "$BASE_BRANCH" ]]; then
    echo -e "${RED}✗ Tu es sur ${BASE_BRANCH} — checkout ta feature branch d'abord${NC}"
    exit 1
  fi

  # ── 6. Switch main + pull ───────────────────────────────
  echo -e "${CYAN}⬇ Switch sur ${BASE_BRANCH} + pull...${NC}"
  git -C "$git_root" switch "$BASE_BRANCH" --quiet
  git -C "$git_root" pull origin "$BASE_BRANCH" --quiet 2>&1 | tail -1
  echo -e "${GREEN}✓ ${BASE_BRANCH} à jour${NC}"

  echo -e "${CYAN}↩ Retour sur ${current_branch}...${NC}"
  git -C "$git_root" switch "$current_branch" --quiet
  echo -e "${GREEN}✓ De retour sur ${current_branch}${NC}"
  echo ""

  # ── 7. Diff ─────────────────────────────────────────────
  echo -e "${BOLD}📂 Diff ${BASE_BRANCH} ↔ ${current_branch} — ${target_dir}${NC}"

  local diff_content diff_stat commits

  diff_stat=$(git -C "$git_root" diff "${BASE_BRANCH}...${current_branch}" --stat -- "$target_dir" 2>/dev/null || true)
  diff_content=$(git -C "$git_root" diff "${BASE_BRANCH}...${current_branch}" -- "$target_dir" 2>/dev/null || true)
  commits=$(git -C "$git_root" log "${BASE_BRANCH}..${current_branch}" --oneline --no-merges -- "$target_dir" 2>/dev/null || true)

  echo "${diff_stat:-"(aucune stat)"}"
  echo ""

  if [[ -z "$diff_content" ]]; then
    echo -e "${YELLOW}⚠ Aucune différence détectée${NC}"
    write_empty_report "$output_path" "$current_branch" "$target_dir" \
      "Aucune modification détectée dans \`${target_dir}\` entre \`${BASE_BRANCH}\` et \`${current_branch}\`. Rien à signaler."
    echo -e "${GREEN}✅ Rapport créé : ${output_path}${NC}"
    exit 0
  fi

  # ── 8. Prompt + Claude ──────────────────────────────────
  local prompt
  prompt=$(cat <<EOF
Tu es un expert code reviewer senior (PHP/Symfony, TypeScript/React, bonnes pratiques).

Effectue une code review complète des changements suivants.

## Contexte
- Branche : \`${current_branch}\` → \`${BASE_BRANCH}\`
- Scope : \`${target_dir}\`
- Date : $(date '+%d/%m/%Y %H:%M')

## Commits
${commits:-"(aucun commit spécifique au scope)"}

## Statistiques
${diff_stat}

## Diff
\`\`\`diff
${diff_content:0:20000}
\`\`\`

---

Génère un rapport Markdown avec EXACTEMENT cette structure :

# Code Review — \`${current_branch}\`

> **Scope :** \`${target_dir}\`
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

  echo -e "${BOLD}🧠 Analyse Claude en cours...${NC}"

  local claude_output claude_exit=0
  claude_output=$(echo "$prompt" | claude -p --output-format text 2>/tmp/claude-err.log) || claude_exit=$?

  if [[ $claude_exit -ne 0 ]] || [[ -z "$claude_output" ]]; then
    echo -e "${YELLOW}⚠ Claude erreur (exit: ${claude_exit})${NC}"
    [[ -s /tmp/claude-err.log ]] && cat /tmp/claude-err.log
    write_empty_report "$output_path" "$current_branch" "$target_dir" \
      "Claude n'a pas pu générer la review. Vérifie \`claude --version\`."
  else
    echo "$claude_output" > "$output_path"
  fi

  # ── 9. Résumé ───────────────────────────────────────────
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
