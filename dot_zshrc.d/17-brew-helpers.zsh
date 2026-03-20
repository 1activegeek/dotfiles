# 17-brew-helpers.zsh — Homebrew sync and export helpers

# Export current Homebrew state to chezmoi source for comparison
brew-export() {
  local output
  output="$(chezmoi source-path)/Brewfile.current"
  echo "Exporting current Homebrew state to: $output"
  brew bundle dump --file="$output" --force
  echo "Done. Compare with .chezmoidata/packages.yaml to see drift."
}

# Sync installed packages with the chezmoi-managed package list
brew-sync() {
  local brewfile
  brewfile="$(mktemp)"
  trap 'rm -f "$brewfile"' INT TERM HUP

  # Re-apply the brew bundle script to get latest Brewfile
  echo "==> Applying brew bundle (this may take a moment)..."
  chezmoi apply --include=scripts 2>/dev/null || {
    echo "    Note: chezmoi apply returned non-zero (some scripts may have been skipped)"
  }

  # Check for packages not in chezmoi's Brewfile
  echo "==> Generating current Brewfile for comparison..."
  brew bundle dump --file="$brewfile" --force 2>/dev/null

  echo "==> Checking for untracked packages..."
  local cleanup_output
  cleanup_output="$(brew bundle cleanup --file="$brewfile" 2>/dev/null || true)"

  if [[ -n "$cleanup_output" ]]; then
    echo ""
    echo "The following packages are installed but not in your package list:"
    echo "$cleanup_output"
    echo ""
    read -r "confirm?Remove these packages? [y/N]: "
    if [[ "$(echo "${confirm:-n}" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
      brew bundle cleanup --file="$brewfile" --force
      echo "==> Cleanup complete."
    else
      echo "==> Skipped cleanup."
    fi
  else
    echo "==> All packages accounted for."
  fi
}

# Interactive diff & merge between Homebrew state and packages.yaml
brew-diff() {
  local chezmoi_src packages_yaml tmpdir brewfile
  chezmoi_src="$(chezmoi source-path)"
  packages_yaml="$chezmoi_src/.chezmoidata/packages.yaml"
  tmpdir="$(mktemp -d)"
  brewfile="$tmpdir/Brewfile"

  _brew_diff_cleanup() { rm -rf "$tmpdir" 2>/dev/null; stty sane 2>/dev/null; }
  trap '_brew_diff_cleanup; return 130' INT
  trap '_brew_diff_cleanup' TERM HUP

  if [[ ! -f "$packages_yaml" ]]; then
    echo "Error: packages.yaml not found at $packages_yaml" >&2
    _brew_diff_cleanup
    return 1
  fi

  # ── Colors ──
  local green='\033[0;32m' red='\033[0;31m' bold='\033[1m' dim='\033[2m'
  local cyan='\033[0;36m' yellow='\033[0;33m' reset='\033[0m'

  echo ""
  echo "${bold}═══════════════════════════════════════════════${reset}"
  echo "${bold}  brew-diff: Homebrew ↔ packages.yaml${reset}"
  echo "${bold}═══════════════════════════════════════════════${reset}"
  echo ""
  echo "Scanning Homebrew and packages.yaml..."
  echo ""

  # ── Phase 0: Dump current Homebrew state ──
  brew bundle dump --file="$brewfile" --force 2>/dev/null || {
    echo "Error: brew bundle dump failed" >&2
    _brew_diff_cleanup
    return 1
  }

  # ── Parse Brewfile into sorted lists ──
  # NOTE: All awk scripts use BSD awk syntax (no GNU extensions)
  local bf_taps_file="$tmpdir/bf_taps"
  local bf_brews_file="$tmpdir/bf_brews"
  local bf_casks_file="$tmpdir/bf_casks"
  local bf_mas_file="$tmpdir/bf_mas"

  awk '/^tap /  { gsub(/"/, "", $2); print $2 }' "$brewfile" | sort > "$bf_taps_file"
  awk '/^brew / { gsub(/"/, "", $2); gsub(/,.*/, "", $2); print $2 }' "$brewfile" | sort > "$bf_brews_file"
  awk '/^cask / { gsub(/"/, "", $2); gsub(/,.*/, "", $2); print $2 }' "$brewfile" | sort > "$bf_casks_file"

  # MAS: output "id|name" pairs (BSD awk compatible)
  awk '/^mas / {
    n = $0; sub(/^mas "/, "", n); sub(/".*/, "", n)
    id = $0; sub(/.*id:[[:space:]]*/, "", id); sub(/[^0-9].*/, "", id)
    if (id != "") print id "|" n
  }' "$brewfile" | sort > "$bf_mas_file"

  # ── Parse packages.yaml (section-based format) ──
  local py_taps_file="$tmpdir/py_taps"
  local py_brews_file="$tmpdir/py_brews"
  local py_casks_file="$tmpdir/py_casks"
  local py_mas_file="$tmpdir/py_mas"

  # Taps: lines under taps: section (simple "  - tapname" format)
  awk '
    /^taps:/ { insect=1; next }
    /^[a-z]/ { insect=0 }
    insect && /^[[:space:]]*- / {
      gsub(/^[[:space:]]*- /, "")
      gsub(/[[:space:]]*$/, "")
      if ($0 !~ /^#/) print
    }
  ' "$packages_yaml" | sort > "$py_taps_file"

  # Formulae: bare strings and flow-mappings under formulae:
  awk '
    /^formulae:/ { insect=1; next }
    /^[a-z]/ { insect=0 }
    insect && /^[[:space:]]*#/ { next }
    insect && /^[[:space:]]*- \{/ {
      n = $0; sub(/.*name:[[:space:]]*/, "", n); sub(/[,} ].*/, "", n)
      if (n != "") print n
      next
    }
    insect && /^[[:space:]]*- / {
      gsub(/^[[:space:]]*- /, ""); gsub(/[[:space:]]*$/, "")
      if ($0 != "") print
    }
  ' "$packages_yaml" | sort > "$py_brews_file"

  # Casks: bare strings and flow-mappings under casks:
  awk '
    /^casks:/ { insect=1; next }
    /^[a-z]/ { insect=0 }
    insect && /^[[:space:]]*#/ { next }
    insect && /^[[:space:]]*- \{/ {
      n = $0; sub(/.*name:[[:space:]]*/, "", n); sub(/[,} ].*/, "", n)
      if (n != "") print n
      next
    }
    insect && /^[[:space:]]*- / {
      gsub(/^[[:space:]]*- /, ""); gsub(/[[:space:]]*$/, "")
      if ($0 != "") print
    }
  ' "$packages_yaml" | sort > "$py_casks_file"

  # MAS: extract id from flow-mappings under mas:
  awk '
    /^mas:/ { insect=1; next }
    /^[a-z]/ { insect=0 }
    insect && /^[[:space:]]*#/ { next }
    insect && /^[[:space:]]*- \{/ {
      id = $0; sub(/.*id:[[:space:]]*"/, "", id); sub(/".*/, "", id)
      if (id != "") print id
    }
  ' "$packages_yaml" | sort > "$py_mas_file"

  # ── Compute diffs ──
  # Items installed but NOT in packages.yaml
  local add_taps_file="$tmpdir/add_taps"
  local add_brews_file="$tmpdir/add_brews"
  local add_casks_file="$tmpdir/add_casks"
  local add_mas_file="$tmpdir/add_mas"

  comm -23 "$bf_taps_file" "$py_taps_file" > "$add_taps_file"
  comm -23 "$bf_brews_file" "$py_brews_file" > "$add_brews_file"
  comm -23 "$bf_casks_file" "$py_casks_file" > "$add_casks_file"
  # MAS: compare on ID only (first field)
  awk -F'|' '{ print $1 }' "$bf_mas_file" | sort > "$tmpdir/bf_mas_ids"
  comm -23 "$tmpdir/bf_mas_ids" "$py_mas_file" > "$tmpdir/add_mas_ids"
  # Reconstruct add_mas with names
  while IFS= read -r id; do
    local mas_name
    mas_name="$(grep "^${id}|" "$bf_mas_file" | cut -d'|' -f2)"
    echo "${id}|${mas_name}"
  done < "$tmpdir/add_mas_ids" > "$add_mas_file"

  # Items in packages.yaml but NOT installed
  local rm_taps_file="$tmpdir/rm_taps"
  local rm_brews_file="$tmpdir/rm_brews"
  local rm_casks_file="$tmpdir/rm_casks"
  local rm_mas_file="$tmpdir/rm_mas"

  comm -23 "$py_taps_file" "$bf_taps_file" > "$rm_taps_file"
  comm -23 "$py_brews_file" "$bf_brews_file" > "$rm_brews_file"
  comm -23 "$py_casks_file" "$bf_casks_file" > "$rm_casks_file"
  comm -23 "$py_mas_file" "$tmpdir/bf_mas_ids" > "$tmpdir/rm_mas_ids"
  # Reconstruct rm_mas with names from packages.yaml
  while IFS= read -r id; do
    local mas_name
    mas_name="$(awk -v id="$id" '
      $0 ~ "id:[[:space:]]*\"" id "\"" {
        n = $0; sub(/.*name:[[:space:]]*"/, "", n); sub(/".*/, "", n)
        print n
      }
    ' "$packages_yaml")"
    echo "${id}|${mas_name}"
  done < "$tmpdir/rm_mas_ids" > "$rm_mas_file"

  # ── Build numbered lists ──
  local -a add_items=()   # "type|ref|name" entries
  local -a rm_items=()

  while IFS= read -r t; do [[ -n "$t" ]] && add_items+=("tap|$t|"); done < "$add_taps_file"
  while IFS= read -r b; do [[ -n "$b" ]] && add_items+=("brew|$b|"); done < "$add_brews_file"
  while IFS= read -r c; do [[ -n "$c" ]] && add_items+=("cask|$c|"); done < "$add_casks_file"
  while IFS='|' read -r id name; do [[ -n "$id" ]] && add_items+=("mas|$id|$name"); done < "$add_mas_file"

  while IFS= read -r t; do [[ -n "$t" ]] && rm_items+=("tap|$t|"); done < "$rm_taps_file"
  while IFS= read -r b; do [[ -n "$b" ]] && rm_items+=("brew|$b|"); done < "$rm_brews_file"
  while IFS= read -r c; do [[ -n "$c" ]] && rm_items+=("cask|$c|"); done < "$rm_casks_file"
  while IFS='|' read -r id name; do [[ -n "$id" ]] && rm_items+=("mas|$id|$name"); done < "$rm_mas_file"

  local add_count=${#add_items[@]}
  local rm_count=${#rm_items[@]}

  # ── Display diff ──
  if (( add_count == 0 && rm_count == 0 )); then
    echo "${green}${bold}Everything in sync!${reset}"
    return 0
  fi

  if (( add_count > 0 )); then
    echo "${green}${bold}── Installed but NOT in packages.yaml ──${reset}"
    echo ""
    local i
    for (( i=1; i<=add_count; i++ )); do
      local entry="${add_items[$i]}"
      local etype="${entry%%|*}"
      local rest="${entry#*|}"
      local eref="${rest%%|*}"
      local ename="${rest#*|}"
      if [[ "$etype" == "mas" && -n "$ename" ]]; then
        printf "   ${green}%2d) [%-4s] %s (%s)${reset}\n" "$i" "$etype" "$ename" "$eref"
      else
        printf "   ${green}%2d) [%-4s] %s${reset}\n" "$i" "$etype" "$eref"
      fi
    done
    echo ""
  fi

  if (( rm_count > 0 )); then
    echo "${red}${bold}── In packages.yaml but NOT installed ──${reset}"
    echo ""
    local i
    for (( i=1; i<=rm_count; i++ )); do
      local entry="${rm_items[$i]}"
      local etype="${entry%%|*}"
      local rest="${entry#*|}"
      local eref="${rest%%|*}"
      local ename="${rest#*|}"
      if [[ "$etype" == "mas" && -n "$ename" ]]; then
        printf "   ${red}%2d) [%-4s] %s (%s)${reset}\n" "$i" "$etype" "$ename" "$eref"
      else
        printf "   ${red}%2d) [%-4s] %s${reset}\n" "$i" "$etype" "$eref"
      fi
    done
    echo ""
  fi

  echo "${bold}── ${green}${add_count} to add${reset}${bold} · ${red}${rm_count} to remove${reset}${bold} ──${reset}"
  echo ""

  # ── Phase 2: Interactive menu ──
  # Reset terminal — brew bundle dump can corrupt stty settings
  stty sane 2>/dev/null
  local modified=false

  while true; do
    echo "What would you like to do?"
    echo ""
    (( add_count > 0 )) && echo "  a) Add items to packages.yaml"
    (( rm_count > 0 ))  && echo "  r) Remove items from packages.yaml"
    echo "  q) Quit"
    echo ""
    local choice
    read -r "choice?Choice: "

    case "$choice" in
      a|A)
        if (( add_count == 0 )); then
          echo "Nothing to add."
          continue
        fi
        echo ""
        echo "Select items to add (comma-separated numbers, or * for all):"
        echo ""
        local i
        for (( i=1; i<=add_count; i++ )); do
          local entry="${add_items[$i]}"
          local etype="${entry%%|*}"
          local rest="${entry#*|}"
          local eref="${rest%%|*}"
          local ename="${rest#*|}"
          if [[ "$etype" == "mas" && -n "$ename" ]]; then
            printf "   %2d) [%-4s] %s (%s)\n" "$i" "$etype" "$ename" "$eref"
          else
            printf "   %2d) [%-4s] %s\n" "$i" "$etype" "$eref"
          fi
        done
        echo ""
        local selection
        read -r "selection?Selection: "

        local -a selected_indices=()
        if [[ "$selection" == "*" ]]; then
          for (( i=1; i<=add_count; i++ )); do
            selected_indices+=("$i")
          done
        else
          IFS=',' read -rA parts <<< "$selection"
          for p in "${parts[@]}"; do
            p="${p// /}"
            if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= add_count )); then
              selected_indices+=("$p")
            fi
          done
        fi

        if (( ${#selected_indices[@]} == 0 )); then
          echo "No valid items selected."
          echo ""
          continue
        fi

        for idx in "${selected_indices[@]}"; do
          local entry="${add_items[$idx]}"
          local etype="${entry%%|*}"
          local rest="${entry#*|}"
          local eref="${rest%%|*}"
          local ename="${rest#*|}"

          # Determine which section to insert into
          local section_key
          case "$etype" in
            tap)  section_key="taps" ;;
            brew) section_key="formulae" ;;
            cask) section_key="casks" ;;
            mas)  section_key="mas" ;;
          esac

          # Build the YAML entry
          local new_entry
          if [[ "$etype" == "mas" && -n "$ename" ]]; then
            new_entry="  - { id: \"${eref}\", name: \"${ename}\" }"
          else
            new_entry="  - ${eref}"
          fi

          # Insert alphabetically within the section
          awk -v section="${section_key}:" -v entry="$new_entry" -v ref="$eref" '
            BEGIN { insect=0; inserted=0 }
            $0 == section { insect=1; print; next }
            insect && !inserted {
              # End of section: line starting with non-space or EOF-like
              if (/^[a-z]/ || /^$/) {
                print entry
                inserted=1
                insect=0
                print
                next
              }
              # Skip comments
              if (/^[[:space:]]*#/) { print; next }
              # Extract sort key from current line
              curr = $0
              gsub(/^[[:space:]]*- /, "", curr)
              gsub(/\{[[:space:]]*name:[[:space:]]*/, "", curr)
              gsub(/\{[[:space:]]*id:[[:space:]]*"/, "", curr)
              gsub(/".*/, "", curr)
              gsub(/,.*/, "", curr)
              gsub(/[[:space:]]*$/, "", curr)
              if (ref < curr) {
                print entry
                inserted=1
                insect=0
              }
            }
            { print }
            END { if (!inserted) print entry }
          ' "$packages_yaml" > "$tmpdir/yaml_tmp" && mv "$tmpdir/yaml_tmp" "$packages_yaml"
          modified=true
          echo "  ✓ Added ${etype} ${eref} → ${section_key}"
        done
        echo ""
        ;;

      r|R)
        if (( rm_count == 0 )); then
          echo "Nothing to remove."
          continue
        fi
        echo ""
        echo "Select items to remove (comma-separated numbers, or * for all):"
        echo ""
        local i
        for (( i=1; i<=rm_count; i++ )); do
          local entry="${rm_items[$i]}"
          local etype="${entry%%|*}"
          local rest="${entry#*|}"
          local eref="${rest%%|*}"
          local ename="${rest#*|}"
          if [[ "$etype" == "mas" && -n "$ename" ]]; then
            printf "   %2d) [%-4s] %s (%s)\n" "$i" "$etype" "$ename" "$eref"
          else
            printf "   %2d) [%-4s] %s\n" "$i" "$etype" "$eref"
          fi
        done
        echo ""
        local selection
        read -r "selection?Selection: "

        local -a selected_indices=()
        if [[ "$selection" == "*" ]]; then
          for (( i=1; i<=rm_count; i++ )); do
            selected_indices+=("$i")
          done
        else
          IFS=',' read -rA parts <<< "$selection"
          for p in "${parts[@]}"; do
            p="${p// /}"
            if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= rm_count )); then
              selected_indices+=("$p")
            fi
          done
        fi

        if (( ${#selected_indices[@]} == 0 )); then
          echo "No valid items selected."
          echo ""
          continue
        fi

        for idx in "${selected_indices[@]}"; do
          local entry="${rm_items[$idx]}"
          local etype="${entry%%|*}"
          local rest="${entry#*|}"
          local eref="${rest%%|*}"
          local ename="${rest#*|}"

          if [[ "$etype" == "tap" ]]; then
            # Remove tap line
            grep -v "^[[:space:]]*- ${eref}[[:space:]]*$" "$packages_yaml" > "$tmpdir/yaml_tmp" \
              && mv "$tmpdir/yaml_tmp" "$packages_yaml"
            echo "  ✓ Removed tap ${eref}"
          elif [[ "$etype" == "mas" ]]; then
            # Remove MAS line matching id
            local escaped_ref
            escaped_ref="$(printf '%s' "$eref" | sed 's/[.[\/*^$]/\\&/g')"
            grep -v "id:[[:space:]]*\"${escaped_ref}\"" "$packages_yaml" > "$tmpdir/yaml_tmp" \
              && mv "$tmpdir/yaml_tmp" "$packages_yaml"
            echo "  ✓ Removed mas ${eref}"
          else
            # Remove formula/cask line — match bare string or flow-mapping name
            local escaped_ref
            escaped_ref="$(printf '%s' "$eref" | sed 's/[.[\/*^$@]/\\&/g')"
            grep -vE "^[[:space:]]*- ${escaped_ref}[[:space:]]*$|name:[[:space:]]*${escaped_ref}[,} ]" "$packages_yaml" > "$tmpdir/yaml_tmp" \
              && mv "$tmpdir/yaml_tmp" "$packages_yaml"
            echo "  ✓ Removed ${etype} ${eref}"
          fi
          modified=true
        done
        echo ""
        ;;

      q|Q)
        break
        ;;

      *)
        echo "Invalid choice."
        echo ""
        ;;
    esac
  done

  # ── Commit & push if modified ──
  if [[ "$modified" == true ]]; then
    echo ""
    echo "${bold}Committing changes...${reset}"
    (
      cd "$chezmoi_src" || { echo "Error: cannot cd to $chezmoi_src" >&2; return 1; }
      git add .chezmoidata/packages.yaml
      if git commit -m "brew-diff: update packages.yaml"; then
        echo "${green}✓ Committed.${reset}"
        if git push; then
          echo "${green}✓ Pushed.${reset}"
        else
          echo "${yellow}⚠ Push failed — commit is local. Push manually when ready.${reset}"
        fi
      else
        echo "${yellow}⚠ Commit failed — check git status in $chezmoi_src${reset}"
      fi
    )
  else
    echo "No changes made."
  fi

  _brew_diff_cleanup
}
