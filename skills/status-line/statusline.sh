#!/usr/bin/env bash
# Claude Code status line — stylé 🔥
# Reçoit un JSON sur stdin décrivant la session.

input=$(cat)

# --- Couleurs (256) ---
RESET='\033[0m'
DIM='\033[2m'
B='\033[1m'
# palette
C_MODEL='\033[38;5;213m'   # rose/violet
C_DIR='\033[38;5;39m'      # bleu cyan
C_GIT='\033[38;5;220m'     # jaune
C_GIT_DIRTY='\033[38;5;208m' # orange
C_OK='\033[38;5;48m'       # vert
C_WARN='\033[38;5;203m'    # rouge clair
C_COST='\033[38;5;141m'    # violet doux
C_TOK='\033[38;5;81m'      # cyan clair (tokens session)
C_DAY='\033[38;5;111m'     # bleu (tokens jour)
C_SEP='\033[38;5;240m'     # gris

SEP="${C_SEP} ${RESET}"

# Formate un nombre de tokens : 1234 -> 1.2k, 1234567 -> 1.2M
humanize() {
  LC_ALL=C awk -v n="${1:-0}" 'BEGIN{
    if (n >= 1000000)      printf "%.1fM", n/1000000;
    else if (n >= 1000)    printf "%.1fk", n/1000;
    else                   printf "%d", n;
  }'
}

# Somme des tokens sur un flux JSONL : renvoie "<neufs> <cache_read>"
#   neufs = input + output + cache_creation (vraie consommation)
#   cache_read = relectures du contexte (gonflé, facturé ~10x moins)
sum_tokens() {
  jq -rs '[.[] | .message.usage // empty] |
    [ (map((.input_tokens//0)+(.output_tokens//0)+(.cache_creation_input_tokens//0))|add // 0),
      (map(.cache_read_input_tokens//0)|add // 0) ] | "\(.[0]) \(.[1])"' 2>/dev/null
}

# Taille du contexte courant = dernière entrée avec usage
# (input + cache_read + cache_creation), ce qui charge le prompt actuel
ctx_tokens() {
  jq -s '[.[] | .message.usage // empty] | last
    | ((.input_tokens//0)+(.cache_read_input_tokens//0)+(.cache_creation_input_tokens//0)) // 0' 2>/dev/null
}

# --- Extraction JSON (un seul appel jq ; séparateur = Unit Separator \x1f
#     non-blanc, sinon `read` fusionne les champs vides consécutifs) ---
IFS=$'\x1f' read -r model cur_dir project_dir cost added removed version transcript <<< "$(
  echo "$input" | jq -j '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // .cwd // ""),
    (.workspace.project_dir // ""),
    (.cost.total_cost_usd // ""),
    (.cost.total_lines_added // ""),
    (.cost.total_lines_removed // ""),
    (.version // ""),
    (.transcript_path // "")
  ] | map(tostring) | join("")'
)"

# --- Dossier (relatif au projet si possible) ---
if [ -n "$project_dir" ] && [ "$cur_dir" != "$project_dir" ]; then
  dir_label="$(basename "$project_dir")/$(basename "$cur_dir")"
else
  dir_label="$(basename "${cur_dir:-$PWD}")"
fi

# --- Git ---
git_part=""
if cd "${cur_dir:-$PWD}" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    gcolor="$C_GIT_DIRTY"; gmark="●"
  else
    gcolor="$C_GIT"; gmark="✓"
  fi
  # ahead/behind
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
  track=""
  if [ -n "$upstream" ]; then
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)
    [ "${ahead:-0}" -gt 0 ] && track="${track} ⇡${ahead}"
    [ "${behind:-0}" -gt 0 ] && track="${track} ⇣${behind}"
  fi
  git_part="${SEP}${gcolor} ${gmark} ${branch}${track}${RESET}"
fi

# --- Coût / lignes ---
cost_part=""
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  cost_fmt=$(LC_ALL=C awk -v c="$cost" 'BEGIN{printf "%.3f", c}' 2>/dev/null || echo "$cost")
  cost_part="${SEP}${C_COST} \$${cost_fmt}${RESET}"
fi
diff_part=""
if { [ -n "$added" ] && [ "$added" != "0" ]; } || { [ -n "$removed" ] && [ "$removed" != "0" ]; }; then
  diff_part="${SEP}${C_OK}+${added:-0}${RESET}${C_SEP}/${RESET}${C_WARN}-${removed:-0}${RESET}"
fi

# --- Tokens (session + jour) ---
tok_part=""
# Prompt actuel : taille du contexte courant (dernière entrée du transcript)
# + jauge en % de la fenêtre du modèle (1M si "(1M)", sinon 200k)
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  ctx_tok=$(ctx_tokens < "$transcript")
  if [ -n "$ctx_tok" ] && [ "$ctx_tok" != "0" ] && [ "$ctx_tok" != "null" ]; then
    case "$model" in
      *1M*) limit=1000000 ;;
      *)    limit=200000 ;;
    esac
    pct=$(( ctx_tok * 100 / limit ))
    # couleur selon remplissage
    if   [ "$pct" -ge 80 ]; then cctx="$C_WARN"
    elif [ "$pct" -ge 50 ]; then cctx="$C_GIT_DIRTY"
    else                         cctx="$C_TOK"
    fi
    # jauge 8 cellules
    filled=$(( (pct * 8 + 99) / 100 )); [ "$filled" -gt 8 ] && filled=8
    bar=""; i=0
    while [ "$i" -lt 8 ]; do
      if [ "$i" -lt "$filled" ]; then bar="${bar}▓"; else bar="${bar}░"; fi
      i=$(( i + 1 ))
    done
    tok_part="${SEP}${cctx}◧ ${bar} ${pct}% ${C_SEP}($(humanize "$ctx_tok"))${RESET}"
  fi
fi
# Jour : tous les transcrits dont le timestamp est aujourd'hui.
# Scanner 25+ Mo à chaque rendu est lent → cache de 15s dans /tmp.
today=$(date +%Y-%m-%d)
cache="/tmp/cc-statusline-day-${today}"
now=$(date +%s)
day_new=""; day_cache=""
if [ -f "$cache" ]; then
  read -r c_epoch c_new c_cache < "$cache" 2>/dev/null
  if [ -n "$c_epoch" ] && [ $(( now - c_epoch )) -lt 15 ]; then
    day_new="$c_new"; day_cache="$c_cache"
  fi
fi
if [ -z "$day_new" ]; then
  read -r day_new day_cache <<< "$(grep -h "\"timestamp\":\"$today" ~/.claude/projects/*/*.jsonl 2>/dev/null | sum_tokens)"
  printf '%s %s %s\n' "$now" "${day_new:-0}" "${day_cache:-0}" > "$cache" 2>/dev/null
fi
if [ -n "$day_new" ] && [ "$day_new" != "0" ]; then
  tok_part="${tok_part}${SEP}${C_DAY}∑ $(humanize "$day_new")/j${RESET}"
  [ -n "$day_cache" ] && [ "$day_cache" != "0" ] \
    && tok_part="${tok_part}${C_SEP} +$(humanize "$day_cache") cache${RESET}"
fi

# --- Assemblage ---
printf "${C_MODEL}${B}✦ %s${RESET}${SEP}${C_DIR} %s${RESET}%b%b%b%b" \
  "$model" "$dir_label" "$git_part" "$cost_part" "$diff_part" "$tok_part"
