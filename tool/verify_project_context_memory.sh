#!/usr/bin/env bash
# ==============================================================================
# verify_project_context_memory.sh
#
# Automated Opaque-Box E2E Validation Runner for Antigravity Persistent
# Project-Context Memory System (Requirements R1 - R5).
#
# Validates Tiers 1-4:
#   Tier 1: Feature Coverage (Existence & structure of all 29 target files + 15 profiles)
#   Tier 2: Boundary & Corner Cases (YAML validity, Invariants 1-7, profile preservation, 0 secrets, 0 code mutation)
#   Tier 3: Cross-Feature Combinations (index.md links, category links, skill references, rule binding)
#   Tier 4: Real-World Scenarios (source/test citation validity, flutter analyze, flutter test)
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# Configuration & Colors
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0

TIER_FILTER="all"
SKIP_FLUTTER=false
VERBOSE=false

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
print_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Automated E2E Validation Runner for Project-Context Memory System.

Options:
  --tier <1|2|3|4|all>  Run specific validation tier (default: all)
  --skip-flutter        Skip live execution of flutter analyze & flutter test
  --verbose             Enable verbose diagnostic output
  -h, --help            Display this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER_FILTER="$2"
      shift 2
      ;;
    --tier=*)
      TIER_FILTER="${1#*=}"
      shift
      ;;
    --skip-flutter)
      SKIP_FLUTTER=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      print_help
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------
record_pass() {
  local check_id="$1"
  local description="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
  echo -e "  ${GREEN}[PASS]${NC} ${BOLD}${check_id}${NC}: ${description}"
}

record_fail() {
  local check_id="$1"
  local description="$2"
  local details="${3:-}"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
  echo -e "  ${RED}[FAIL]${NC} ${BOLD}${check_id}${NC}: ${description}"
  if [[ -n "$details" ]]; then
    echo -e "         ${RED}Detail:${NC} ${details}"
  fi
}

record_skip() {
  local check_id="$1"
  local description="$2"
  local reason="${3:-}"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
  echo -e "  ${YELLOW}[SKIP]${NC} ${BOLD}${check_id}${NC}: ${description} (${reason})"
}

log_info() {
  echo -e "${CYAN}==>${NC} ${BOLD}$1${NC}"
}

# ------------------------------------------------------------------------------
# TIER 1: Feature Coverage (Existence & Structural Completeness)
# ------------------------------------------------------------------------------
run_tier_1() {
  log_info "Running Tier 1: Feature Coverage (Existence of Target Artifacts)"

  # T1.1: Always-On Rule
  local rule_file=".agents/rules/project-context-memory.md"
  if [[ -f "$rule_file" && -s "$rule_file" ]]; then
    record_pass "T1.1" "Always-on rule file exists and is non-empty ($rule_file)"
  else
    record_fail "T1.1" "Always-on rule file missing or empty ($rule_file)"
  fi

  # T1.2: Skill Definition & References & Templates
  local skill_file=".agents/skills/project-context-memory/SKILL.md"
  if [[ -f "$skill_file" && -s "$skill_file" ]]; then
    record_pass "T1.2a" "Skill main file exists and is non-empty ($skill_file)"
  else
    record_fail "T1.2a" "Skill main file missing or empty ($skill_file)"
  fi

  local references=(
    "knowledge-model.md"
    "classification-rules.md"
    "update-policy.md"
    "workflow.md"
  )
  for ref in "${references[@]}"; do
    local ref_path=".agents/skills/project-context-memory/references/$ref"
    if [[ -f "$ref_path" && -s "$ref_path" ]]; then
      record_pass "T1.2b" "Reference guide exists: $ref"
    else
      record_fail "T1.2b" "Reference guide missing or empty: $ref_path"
    fi
  done

  local templates=(
    "business-rule.md"
    "convention.md"
    "architecture-decision.md"
    "implementation-decision.md"
    "domain-knowledge.md"
  )
  for tpl in "${templates[@]}"; do
    local tpl_path=".agents/skills/project-context-memory/templates/$tpl"
    if [[ -f "$tpl_path" && -s "$tpl_path" ]]; then
      record_pass "T1.2c" "Template file exists: $tpl"
    else
      record_fail "T1.2c" "Template file missing or empty: $tpl_path"
    fi
  done

  # T1.3: Knowledge Repository Directory & Core Documentation
  local root_docs=(
    "project-context/index.md"
    "project-context/README.md"
    "project-context/architecture/overview.md"
  )
  for doc in "${root_docs[@]}"; do
    if [[ -f "$doc" && -s "$doc" ]]; then
      record_pass "T1.3a" "Core knowledge document exists: $doc"
    else
      record_fail "T1.3a" "Core knowledge document missing or empty: $doc"
    fi
  done

  local categories=(
    "business-rules"
    "conventions"
    "decisions"
    "implementation"
    "domain"
  )
  for cat in "${categories[@]}"; do
    local cat_readme="project-context/knowledge/$cat/README.md"
    if [[ -f "$cat_readme" && -s "$cat_readme" ]]; then
      record_pass "T1.3b" "Category catalog README exists: $cat/README.md"
    else
      record_fail "T1.3b" "Category catalog README missing or empty: $cat_readme"
    fi
  done

  # T1.4: Preserved Scanner Profiles (15 files)
  local profile_count=0
  local missing_profiles=()
  for i in $(seq -w 1 15); do
    local pfile
    pfile=$(find project-context/profiles -maxdepth 1 -name "${i}-*.md" 2>/dev/null | head -n 1)
    if [[ -n "$pfile" && -f "$pfile" && -s "$pfile" ]]; then
      profile_count=$((profile_count + 1))
    else
      missing_profiles+=("${i}-*.md")
    fi
  done

  if [[ $profile_count -eq 15 ]]; then
    record_pass "T1.4" "All 15 scanner profiles exist and are preserved in project-context/profiles/"
  else
    record_fail "T1.4" "Profiles missing or corrupted (found $profile_count/15)" "Missing: ${missing_profiles[*]}"
  fi

  # T1.5: Initial Bootstrap Knowledge Documents (10 files)
  local bootstrap_docs=(
    "project-context/knowledge/business-rules/br-workout-split-limits.md"
    "project-context/knowledge/business-rules/br-calendar-week-boundaries.md"
    "project-context/knowledge/business-rules/br-estimated-1rm-pr-calculation.md"
    "project-context/knowledge/conventions/conv-clean-architecture-layers.md"
    "project-context/knowledge/conventions/conv-mvvm-changenotifier.md"
    "project-context/knowledge/conventions/conv-flutter-tooling-sandbox-bypass.md"
    "project-context/knowledge/decisions/adr-excel-orm-drive-persistence.md"
    "project-context/knowledge/decisions/adr-cache-first-local-storage.md"
    "project-context/knowledge/decisions/adr-debounced-background-sync.md"
    "project-context/knowledge/domain/dom-workout-splits-and-logging.md"
  )
  for bdoc in "${bootstrap_docs[@]}"; do
    if [[ -f "$bdoc" && -s "$bdoc" ]]; then
      record_pass "T1.5" "Bootstrap document exists: $(basename "$bdoc")"
    else
      record_fail "T1.5" "Bootstrap document missing or empty: $bdoc"
    fi
  done
}

# ------------------------------------------------------------------------------
# TIER 2: Boundary, Schema & Safety Verification
# ------------------------------------------------------------------------------
run_tier_2() {
  log_info "Running Tier 2: Boundary, Schema & Safety Verification"

  # T2.1: SKILL.md YAML Frontmatter Format & Triggers
  local skill_file=".agents/skills/project-context-memory/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    local starts_yaml
    starts_yaml=$(head -n 1 "$skill_file" | tr -d '\r')
    local has_name
    has_name=$(grep -E "^name:\s*project-context-memory" "$skill_file" || true)
    local has_desc
    has_desc=$(grep -E "^description:" "$skill_file" || true)
    local has_slash
    has_slash=$(grep "/project-context-memory" "$skill_file" || true)

    if [[ "$starts_yaml" == "---" && -n "$has_name" && -n "$has_desc" && -n "$has_slash" ]]; then
      record_pass "T2.1a" "SKILL.md has valid YAML frontmatter with unique name and /project-context-memory trigger"
    else
      record_fail "T2.1a" "SKILL.md YAML frontmatter invalid" "starts_yaml='$starts_yaml', has_name='$has_name', has_slash='$has_slash'"
    fi

    # 8 Lifecycle stages
    local stages=("DISCOVER" "CLASSIFY" "RETRIEVE" "APPLY" "IMPLEMENT" "VALIDATE" "PERSIST" "INDEX")
    local stages_found=0
    for stage in "${stages[@]}"; do
      if grep -q "$stage" "$skill_file"; then
        stages_found=$((stages_found + 1))
      fi
    done

    if [[ $stages_found -eq 8 ]]; then
      record_pass "T2.1b" "SKILL.md documents all 8 memory lifecycle stages"
    else
      record_fail "T2.1b" "SKILL.md missing lifecycle stages (found $stages_found/8)"
    fi
  else
    record_fail "T2.1" "SKILL.md does not exist"
  fi

  # T2.2: Rule Invariant 1–7 Presence & Conciseness
  local rule_file=".agents/rules/project-context-memory.md"
  if [[ -f "$rule_file" ]]; then
    local line_count
    line_count=$(wc -l < "$rule_file" | tr -d ' ')
    if [[ $line_count -le 50 ]]; then
      record_pass "T2.2a" "Rule file is concise (<50 lines: $line_count lines)"
    else
      record_fail "T2.2a" "Rule file exceeds 50 lines ($line_count lines)" "Exceeds token budget for always-on rule"
    fi

    # Check for presence of all 7 invariants
    local inv1 inv2 inv3 inv4 inv5 inv6 inv7
    inv1=$(grep -iE "authoritative.*project knowledge|project-context" "$rule_file" || true)
    inv2=$(grep -iE "project-context-memory" "$rule_file" || true)
    inv3=$(grep -iE "progressive disclosure" "$rule_file" || true)
    inv4=$(grep -iE "persist|durable" "$rule_file" || true)
    inv5=$(grep -iE "precedence|assumptions|test" "$rule_file" || true)
    inv6=$(grep -iE "silent|overwrite|replace" "$rule_file" || true)
    inv7=$(grep -iE "ephemeral|temporary" "$rule_file" || true)

    if [[ -n "$inv1" && -n "$inv2" && -n "$inv3" && -n "$inv4" && -n "$inv5" && -n "$inv6" && -n "$inv7" ]]; then
      record_pass "T2.2b" "Rule file contains all 7 essential invariants"
    else
      record_fail "T2.2b" "Rule file missing one or more invariants" "inv1=$inv1, inv2=$inv2, inv3=$inv3, inv4=$inv4, inv5=$inv5, inv6=$inv6, inv7=$inv7"
    fi
  else
    record_fail "T2.2" "Rule file does not exist"
  fi

  # T2.3: Preservation of Profiles & Integrity
  local total_profile_files
  total_profile_files=$(find project-context/profiles -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$total_profile_files" -eq 15 ]]; then
    record_pass "T2.3a" "Exactly 15 profile files present in project-context/profiles/"
  else
    record_fail "T2.3a" "Expected 15 profile files, found $total_profile_files"
  fi

  local p08="project-context/profiles/08-typescript.md"
  if [[ -f "$p08" ]]; then
    if grep -q "Profile 08: Language & Type System" "$p08"; then
      record_pass "T2.3b" "Profile 08 preserved with original name and Dart type system header"
    else
      record_fail "T2.3b" "Profile 08 header altered or corrupted"
    fi
  else
    record_fail "T2.3b" "Profile 08-typescript.md missing"
  fi

  # Profile diff guard: ensure no files in profiles/ were modified beyond initial baseline
  local unbaseline_profile_diff
  unbaseline_profile_diff=$(git diff --name-only project-context/profiles/ 2>/dev/null | grep -v -E "01-architecture.md|03-state.md|04-testing.md" || true)
  if [[ -z "$unbaseline_profile_diff" ]]; then
    record_pass "T2.3c" "Zero un-baseline modifications to project-context/profiles/"
  else
    record_fail "T2.3c" "Unexpected files modified in project-context/profiles/" "$unbaseline_profile_diff"
  fi

  # T2.4: Zero Secrets / Tokens / Credentials Regex Scan
  local secrets_found=0
  local scanned_dirs=(".agents/rules" ".agents/skills/project-context-memory" "project-context")
  local secret_patterns=(
    'AIza[0-9A-Za-z-_]{35}'                                    # Google API Key
    'sk-[a-zA-Z0-9]{20,}'                                      # OpenAI / Generic Secret Key
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'                       # Private Keys
    '(client_secret|access_token|refresh_token|private_key|auth_token)\s*[:=]\s*["'\''][a-zA-Z0-9_\-\.]{12,}["'\'']' # Sensitive tokens
  )

  for dir in "${scanned_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      for pat in "${secret_patterns[@]}"; do
        local matches
        matches=$(grep -rEn "$pat" "$dir" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
          secrets_found=$((secrets_found + 1))
          echo -e "         ${RED}Secret detected in $dir:${NC} $matches"
        fi
      done
    fi
  done

  if [[ $secrets_found -eq 0 ]]; then
    record_pass "T2.4" "Zero secrets, tokens, or private credentials found in persistent memory files"
  else
    record_fail "T2.4" "Secrets or private credentials detected in memory documents!" "$secrets_found potential secrets found"
  fi

  # T2.5: Zero Unintended Code Modifications Gate
  local untracked_code
  untracked_code=$(git status --porcelain lib/ test/ 2>/dev/null | grep -E "^\?\?" || true)
  if [[ -z "$untracked_code" ]]; then
    record_pass "T2.5a" "Zero untracked code or test files introduced into lib/ or test/"
  else
    record_fail "T2.5a" "Untracked files introduced into lib/ or test/" "$untracked_code"
  fi

  # Ensure no new modifications beyond initial baseline
  local extra_modified_code
  extra_modified_code=$(git diff --name-only lib/ test/ 2>/dev/null | grep -v -E "workout_repository|manage_workout_set|exercise_statistics|todays_workout_log|add_workout_set_modal" || true)
  if [[ -z "$extra_modified_code" ]]; then
    record_pass "T2.5b" "Zero un-baseline modifications introduced into lib/ or test/"
  else
    record_fail "T2.5b" "Unexpected modifications found in lib/ or test/" "$extra_modified_code"
  fi
}

# ------------------------------------------------------------------------------
# TIER 3: Cross-Feature Combinations (Link Health & Interoperability)
# ------------------------------------------------------------------------------
run_tier_3() {
  log_info "Running Tier 3: Cross-Feature Combinations (Link Health & Interoperability)"

  # T3.1: Root Index Link Validity
  local index_file="project-context/index.md"
  if [[ -f "$index_file" ]]; then
    local broken_links=()
    local checked_links=0

    while IFS= read -r link; do
      [[ -z "$link" ]] && continue
      checked_links=$((checked_links + 1))
      local clean_target="${link%%#*}"
      clean_target="${clean_target%%\?*}"
      [[ -z "$clean_target" ]] && continue

      local resolved_path=""
      if [[ "$clean_target" == /* ]]; then
        resolved_path="${REPO_ROOT}${clean_target}"
      elif [[ "$clean_target" == ../* ]]; then
        resolved_path="${REPO_ROOT}/${clean_target#../}"
      else
        resolved_path="${REPO_ROOT}/project-context/${clean_target}"
      fi

      if [[ ! -e "$resolved_path" ]]; then
        broken_links+=("$link -> $resolved_path")
      fi
    done < <(grep -oE '\[[^]]+\]\([^)]+\)' "$index_file" | sed -E 's/.*\]\(([^)]+)\)/\1/' | grep -v -E '^(http|mailto)' || true)

    if [[ ${#broken_links[@]} -eq 0 && $checked_links -gt 0 ]]; then
      record_pass "T3.1a" "All internal Markdown links in project-context/index.md resolve to existing files ($checked_links checked)"
    else
      record_fail "T3.1a" "Broken Markdown links in project-context/index.md" "Broken (${#broken_links[@]}): ${broken_links[*]:-None checked}"
    fi

    local has_agents has_context has_arch profile_links_count
    has_agents=$(grep "AGENTS.md" "$index_file" || true)
    has_context=$(grep "PROJECT_CONTEXT.md" "$index_file" || true)
    has_arch=$(grep "architecture/overview.md" "$index_file" || true)
    profile_links_count=$(grep -c "profiles/" "$index_file" || true)

    if [[ -n "$has_agents" && -n "$has_context" && -n "$has_arch" && $profile_links_count -ge 15 ]]; then
      record_pass "T3.1b" "index.md correctly cross-links foundation docs, architecture, and all 15 profiles"
    else
      record_fail "T3.1b" "index.md missing required cross-links" "agents='$has_agents', context='$has_context', arch='$has_arch', profiles=$profile_links_count/15"
    fi
  else
    record_fail "T3.1" "project-context/index.md does not exist"
  fi

  # T3.2: Category READMEs Link Health
  local cat_broken=()
  local total_cat_links=0
  local missing_cat_readmes=0
  local cat_readmes=(
    "project-context/knowledge/business-rules/README.md"
    "project-context/knowledge/conventions/README.md"
    "project-context/knowledge/decisions/README.md"
    "project-context/knowledge/implementation/README.md"
    "project-context/knowledge/domain/README.md"
  )

  for cat_rm in "${cat_readmes[@]}"; do
    if [[ -f "$cat_rm" ]]; then
      local cat_dir
      cat_dir="$(dirname "$cat_rm")"
      while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        total_cat_links=$((total_cat_links + 1))
        local clean_target="${link%%#*}"
        clean_target="${clean_target%%\?*}"
        [[ -z "$clean_target" ]] && continue

        local resolved_path=""
        if [[ "$clean_target" == /* ]]; then
          resolved_path="${REPO_ROOT}${clean_target}"
        elif [[ "$clean_target" == ../* ]]; then
          resolved_path="${cat_dir}/${clean_target}"
        else
          resolved_path="${cat_dir}/${clean_target}"
        fi

        if [[ ! -e "$resolved_path" ]]; then
          cat_broken+=("$cat_rm: $link -> $resolved_path")
        fi
      done < <(grep -oE '\[[^]]+\]\([^)]+\)' "$cat_rm" | sed -E 's/.*\]\(([^)]+)\)/\1/' | grep -v -E '^(http|mailto)' || true)
    else
      missing_cat_readmes=$((missing_cat_readmes + 1))
    fi
  done

  if [[ $missing_cat_readmes -eq 0 && ${#cat_broken[@]} -eq 0 && $total_cat_links -gt 0 ]]; then
    record_pass "T3.2" "All internal links in category README catalogs resolve to existing files ($total_cat_links checked)"
  else
    record_fail "T3.2" "Category README catalogs have missing files or broken links" "Missing READMEs: $missing_cat_readmes/5, Broken links: ${#cat_broken[@]}"
  fi

  # T3.3: Skill References & Templates Interlinking
  local skill_file=".agents/skills/project-context-memory/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    local has_all_refs=true
    for ref in "knowledge-model.md" "classification-rules.md" "update-policy.md" "workflow.md"; do
      if ! grep -q "$ref" "$skill_file"; then
        has_all_refs=false
        break
      fi
    done

    local has_all_tpls=true
    for tpl in "business-rule.md" "convention.md" "architecture-decision.md" "implementation-decision.md" "domain-knowledge.md"; do
      if ! grep -q "$tpl" "$skill_file"; then
        has_all_tpls=false
        break
      fi
    done

    if [[ "$has_all_refs" == true && "$has_all_tpls" == true ]]; then
      record_pass "T3.3" "SKILL.md correctly cross-links all 4 reference guides and 5 templates"
    else
      record_fail "T3.3" "SKILL.md missing references or templates links" "has_all_refs=$has_all_refs, has_all_tpls=$has_all_tpls"
    fi
  else
    record_fail "T3.3" "SKILL.md does not exist"
  fi

  # T3.4: Rule Invariant 2 Skill Delegation Binding
  local rule_file=".agents/rules/project-context-memory.md"
  if [[ -f "$rule_file" ]]; then
    if grep -q "project-context-memory" "$rule_file"; then
      record_pass "T3.4" "Rule Invariant 2 explicitly binds governance to 'project-context-memory' skill"
    else
      record_fail "T3.4" "Rule Invariant 2 does not reference 'project-context-memory' skill"
    fi
  else
    record_fail "T3.4" "Rule file does not exist"
  fi
}

# ------------------------------------------------------------------------------
# TIER 4: Real-World Scenarios (Code Grounding & Regression Gates)
# ------------------------------------------------------------------------------
run_tier_4() {
  log_info "Running Tier 4: Real-World Scenarios (Grounding & Quality Gates)"

  # T4.1: Source Code Citation Validity
  # BR-001 citations
  local f1="lib/domain/models/workout_split.dart"
  if [[ -f "$f1" ]] && grep -q "getMaximumWorkoutDays" "$f1"; then
    record_pass "T4.1a" "BR-001 source citation exists: $f1 (getMaximumWorkoutDays)"
  else
    record_fail "T4.1a" "BR-001 source citation missing in $f1"
  fi

  # BR-002 citations
  local f2="lib/ui/features/weekly_activity/view_models/weekly_activity_view_model.dart"
  if [[ -f "$f2" ]] && grep -q "now.weekday" "$f2"; then
    record_pass "T4.1b" "BR-002 source citation exists: $f2 (weekday logic)"
  else
    record_fail "T4.1b" "BR-002 source citation missing in $f2"
  fi

  # BR-003 citations
  local f3="lib/domain/use_cases/get_exercise_statistics_use_case.dart"
  if [[ -f "$f3" ]] && grep -q "_calculateEstimated1RM" "$f3"; then
    record_pass "T4.1c" "BR-003 source citation exists: $f3 (_calculateEstimated1RM)"
  else
    record_fail "T4.1c" "BR-003 source citation missing in $f3"
  fi

  # ADR-001 & ADR-003 citations
  local f4="lib/data/orm/excel_context.dart"
  local f5="lib/data/services/google_drive_service.dart"
  if [[ -f "$f4" && -f "$f5" ]] && grep -q "syncDailyRecordsToDriveInBackground" "$f5"; then
    record_pass "T4.1d" "ADR source citations exist: excel_context.dart & google_drive_service.dart (syncDailyRecordsToDriveInBackground)"
  else
    record_fail "T4.1d" "ADR source citations missing in $f4 or $f5"
  fi

  # T4.2: Test Code Citation Validity
  # widget_test.dart
  local t1="test/widget_test.dart"
  if [[ -f "$t1" ]] && grep -q "Full Body Split prevents a fourth workout day" "$t1"; then
    record_pass "T4.2a" "BR-001 test citation exists in $t1 ('Full Body Split prevents a fourth workout day')"
  else
    record_fail "T4.2a" "BR-001 test citation missing in $t1"
  fi

  # weekly_activity_test.dart
  local t2="test/weekly_activity_test.dart"
  if [[ -f "$t2" ]] && grep -q "marks logged days in the current Monday-to-Sunday week" "$t2"; then
    record_pass "T4.2b" "BR-002 test citation exists in $t2 ('marks logged days in the current Monday-to-Sunday week')"
  else
    record_fail "T4.2b" "BR-002 test citation missing in $t2"
  fi

  # todays_workout_log_test.dart
  local t3="test/todays_workout_log_test.dart"
  if [[ -f "$t3" ]] && grep -q "renders PR 🏆 badge for the set with highest estimated 1RM" "$t3"; then
    record_pass "T4.2c" "BR-003 test citation exists in $t3 ('renders PR 🏆 badge for the set with highest estimated 1RM')"
  else
    record_fail "T4.2c" "BR-003 test citation missing in $t3"
  fi

  # features_and_optimizations_test.dart
  local t4="test/features_and_optimizations_test.dart"
  if [[ -f "$t4" ]] && grep -q "syncDailyRecordsToDriveInBackground debounces rapid invocations into single execution" "$t4"; then
    record_pass "T4.2d" "ADR-003 test citation exists in $t4 (debounced background sync test)"
  else
    record_fail "T4.2d" "ADR-003 test citation missing in $t4"
  fi

  # T4.3 & T4.4: Static Analysis and Regression Test Execution
  if [[ "$SKIP_FLUTTER" == true ]]; then
    record_skip "T4.3" "flutter analyze quality gate" "Skipped via --skip-flutter"
    record_skip "T4.4" "flutter test quality gate" "Skipped via --skip-flutter"
  else
    log_info "Executing: flutter analyze"
    local analyze_output
    if analyze_output=$(flutter analyze 2>&1); then
      record_pass "T4.3" "flutter analyze passed cleanly with exit code 0"
    else
      record_fail "T4.3" "flutter analyze reported errors or non-zero exit code" "$analyze_output"
    fi

    log_info "Executing: flutter test"
    local test_output
    if test_output=$(flutter test 2>&1); then
      record_pass "T4.4" "flutter test passed cleanly with exit code 0 (all tests passed)"
    else
      record_fail "T4.4" "flutter test reported failures or non-zero exit code" "$test_output"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Main Execution Loop
# ------------------------------------------------------------------------------
echo -e "${BOLD}==============================================================================${NC}"
echo -e "${BOLD} Antigravity Persistent Project-Context Memory System — E2E Test Runner        ${NC}"
echo -e "${BOLD}==============================================================================${NC}"
echo -e "Repository Root: ${REPO_ROOT}"
echo -e "Tier Filter:     ${TIER_FILTER}"
echo -e "Skip Flutter:    ${SKIP_FLUTTER}"
echo ""

case "$TIER_FILTER" in
  1)
    run_tier_1
    ;;
  2)
    run_tier_2
    ;;
  3)
    run_tier_3
    ;;
  4)
    run_tier_4
    ;;
  all)
    run_tier_1
    echo ""
    run_tier_2
    echo ""
    run_tier_3
    echo ""
    run_tier_4
    ;;
  *)
    echo -e "${RED}Invalid tier filter: $TIER_FILTER (valid: 1, 2, 3, 4, all)${NC}"
    exit 1
    ;;
esac

echo ""
echo -e "${BOLD}==============================================================================${NC}"
echo -e "${BOLD} Validation Summary                                                            ${NC}"
echo -e "${BOLD}==============================================================================${NC}"
echo -e "  Total Checks:    ${BOLD}${TOTAL_CHECKS}${NC}"
echo -e "  Passed:          ${GREEN}${BOLD}${PASSED_CHECKS}${NC}"
echo -e "  Failed:          ${RED}${BOLD}${FAILED_CHECKS}${NC}"
echo -e "  Skipped:         ${YELLOW}${BOLD}${SKIPPED_CHECKS}${NC}"
echo -e "${BOLD}==============================================================================${NC}"

if [[ $FAILED_CHECKS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}SUCCESS: All executed validation checks PASSED!${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}FAILURE: $FAILED_CHECKS validation checks FAILED.${NC}"
  exit 1
fi
