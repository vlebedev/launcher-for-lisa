#!/usr/bin/env bash
#
# create-account.sh — one-off root setup for Lisa's account on an Omarchy box.
#
# Run by the owner:  sudo setup/create-account.sh --logins <file> [--repo <url>]
#
# Safe to re-run: every step checks its own state first. Nothing here is
# destructive — the only file that moves is /etc/sddm.conf.d/autologin.conf,
# and it is renamed (backed up), never deleted.
#
# ---------------------------------------------------------------------------
# Verified against this machine (Omarchy 4.0.2 / Hyprland 0.56) before writing.
# Re-verify if Omarchy is upgraded.
# ---------------------------------------------------------------------------
#
# 1. How per-user environment (LANG) reaches the session
#
#    SDDM launches /usr/local/share/wayland-sessions/omarchy.desktop, which is
#      Exec=uwsm start -g -1 -e -D Hyprland hyprland.desktop
#    so the whole session lives under the systemd *user* manager:
#      - wayland-wm-env@Hyprland.service runs `uwsm aux prepare-env`
#        (/usr/lib/systemd/user/wayland-wm-env@.service:21)
#      - wayland-wm@Hyprland.service runs Hyprland itself.
#
#    `uwsm aux prepare-env` sources, per XDG config dir in increasing priority,
#    `uwsm/env`, `uwsm/env.d/*`, `uwsm/env-<desktop>`, `uwsm/env-<desktop>.d/*`
#    (/usr/lib/uwsm/prepare-env.sh:67-84) and then pushes the resulting delta
#    into the systemd user manager's *activation environment*
#    (/usr/share/uwsm/modules/uwsm/main.py:2832-2870). LANG is not in
#    Varnames.never_export (main.py:159-169), so it is exported normally.
#
#    Everything the menu launches goes through `uwsm-app` (see
#    /usr/share/omarchy/bin/omarchy-launch-webapp:13 and o.launch() in
#    /usr/share/omarchy/default/hypr/helpers.lua:108-110), i.e. it is started by
#    that same systemd user manager and therefore inherits the activation
#    environment. So does Hyprland.
#
#    ~/.config/environment.d/*.conf is read by the systemd user manager itself
#    (man 5 environment.d) and so reaches every user unit — including
#    wayland-wm@Hyprland.service and every uwsm-app child.
#
#    => Both mechanisms reach Hyprland *and* menu-launched apps. This script
#       writes BOTH, each in a dedicated drop-in file it owns outright:
#         ~/.config/uwsm/env.d/50-lisa-locale
#         ~/.config/environment.d/50-lisa-locale.conf
#       Neither path is shipped by /etc/skel, so there is nothing to clobber.
#       (~/.bashrc / /etc/locale.conf are deliberately left alone: they do not
#       feed the graphical session, and /etc/locale.conf is system-wide.)
#
# 2. Keyboard layout — /etc/skel/.config/hypr/input.lua
#
#    The skel file ships the whole `hl.config({ input = { ... } })` block
#    commented out (/etc/skel/.config/hypr/input.lua:6-45). Omarchy's own
#    defaults live in /usr/share/omarchy/default/hypr/input.lua:50-75 and are
#    loaded first (via require("default.hypr.omarchy") in hyprland.lua:14,
#    which requires default.hypr.input at omarchy.lua:18); the user's
#    hypr/input.lua is required afterwards (hyprland.lua:20). hl.config() sets
#    individual Hyprland variables, so a later partial call overrides only the
#    keys it names — that is exactly how the owner's own
#    /home/wal/.config/hypr/input.lua:6-44 works.
#
#    => This script APPENDS a marked block with its own hl.config({ input = {
#       kb_layout = "ch", kb_variant = "" } }) rather than trying to uncomment
#       the skel template. Being last, it wins. kb_variant is pinned to "" so a
#       variant inherited from /etc/vconsole.conf's XKBVARIANT (read by
#       default/hypr/input.lua:32) cannot be paired with the "ch" layout.
#
# 3. Idle keys — /etc/skel/.config/omarchy/shell.json
#
#    Shape is {"version":1,"idle":{"screensaver":150,"lock":300}, ...}
#    (/etc/skel/.config/omarchy/shell.json:2-6). Plain integers, seconds.
#
# 4. Does Omarchy's first-login provisioning undo any of this?  NO — with one
#    caveat that this script works around.
#
#    On her first Hyprland start, default/hypr/autostart.lua:7 runs
#    `omarchy-provision-first-run`, which runs `omarchy-provision-user`
#    (/usr/bin/omarchy-provision-first-run:46) and then the scripts in
#    /usr/share/omarchy/install/user/first-run/ (lines 71-93).
#    omarchy-provision-user sources /usr/share/omarchy/install/user/all.sh
#    (line 108) => theme.sh, chromium.sh, git.sh, xcompose.sh, mise*.sh,
#    hardware/*.sh, default-keyring.sh.
#
#    Grepping that entire tree for hyprland.lua / hypr/input.lua / shell.json /
#    environment.d / uwsm/env / omarchy-menu.jsonc / locale / LANG returns
#    exactly one hit, and it is a code comment (install/user/chromium.sh:3).
#    None of the first-run scripts rewrite anything we touch.
#
#    CAVEAT — Omarchy *migrations*. /usr/share/omarchy/migrations/ currently
#    holds 96 scripts, and omarchy-migrate (/usr/bin/omarchy-migrate:88-98)
#    runs every one that has no marker under ~/.local/state/omarchy/migrations/.
#    On this Omarchy that is already handled by /etc/skel, which ships the
#    baseline: /etc/skel/.local/state/omarchy/migrations/ holds one zero-byte
#    marker per shipped migration (96 files, exactly the same name list as
#    /usr/share/omarchy/migrations/*.sh; the directory is owned by the omarchy
#    package, so upgrades keep the two in step). `useradd -m` copies that tree
#    verbatim, so a home seeded from skel starts with *nothing* pending and no
#    migration ever gets the chance to rewrite our files. What skel is saving
#    us from, concretely:
#      - migrations/1781485962.sh:91-94 replaces ~/.config/hypr/input.lua with
#        the packaged copy when the file is "stock" (it compares a sha with the
#        kb_layout/kb_variant lines stripped). That would erase our block.
#      - migrations/1781063758.sh and 1781043107.sh rewrite ~/.config/hypr/
#        hyprland.lua (both are no-ops on a current skel file, but only
#        by luck).
#      - Several shell.json migrations (1780294774, 1784989000, 1785344985,
#        1785189600, 1786099804) rewrite that file wholesale via jq.
#      - 38 of the 96 mention `sudo`. Lisa is deliberately NOT in wheel, so
#        those cannot succeed for her; omarchy-migrate runs under
#        `set -euo pipefail` and would abort, leaving a "Click to run N pending
#        migrations" toast at every login that never clears.
#    Omarchy baselines the accounts it creates itself the same way, from the
#    other end: `omarchy-provision-user --force --first-install`
#    (/usr/bin/omarchy-provision-owner:851) touches a marker for every shipped
#    migration (omarchy-provision-user:114-119).
#
#    => Step 11 below is a FALLBACK, not the load-bearing part. It lays down
#       that same baseline only when ~/.local/state/omarchy/migrations does not
#       exist at all — i.e. on an Omarchy build whose /etc/skel does not ship
#       the markers. On this machine it always finds the skel-seeded directory
#       and reports "migration state already exists (seeded from /etc/skel)",
#       changing nothing. Migrations shipped *after* setup still run normally,
#       and the `done` markers (finalize-user, first-run-user) are never
#       touched, so her real first-run provisioning still happens.
#
# 5. Locale state
#
#    `locale -a` prints generated locales in normalized form ("de_CH.utf8", not
#    "de_CH.UTF-8"), so the check lowercases and strips dashes before matching.
#    The line to enable in /etc/locale.gen is line 125 on this machine:
#        #de_CH.UTF-8 UTF-8
#    (note the trailing whitespace in the shipped file; the sed below tolerates
#    it). /etc/locale.conf stays untouched — that is the system default.
#
# 6. bin/lisa-launcher
#
#    Called per docs/design.md as `lisa-launcher install` with no user session:
#    it must create the timers.target.wants symlink by hand and only try
#    `systemctl --user` when XDG_RUNTIME_DIR exists. This script invokes it via
#    sudo -u lisa -H with HOME set and with XDG_RUNTIME_DIR /
#    DBUS_SESSION_BUS_ADDRESS explicitly unset, so it cannot accidentally reach
#    root's session bus.
#
set -euo pipefail

readonly LISA_USER="lisa"
readonly LISA_GECOS="Elizaveta"
readonly LISA_SHELL="/usr/bin/bash"
readonly DEFAULT_REPO_URL="https://github.com/vlebedev/launcher-for-lisa"
readonly TARGET_LOCALE="de_CH.UTF-8"
readonly KB_LAYOUT="ch"
readonly IDLE_SCREENSAVER=600
readonly IDLE_LOCK=3600
readonly SDDM_AUTOLOGIN="/etc/sddm.conf.d/autologin.conf"
readonly SDDM_AUTOLOGIN_DISABLED="/etc/sddm.conf.d/autologin.conf.disabled"
readonly OMARCHY_MIGRATIONS_DIR="/usr/share/omarchy/migrations"

readonly BLOCK_BEGIN="-- >>> launcher-for-lisa (managed) — keyboard layout"
readonly BLOCK_END="-- <<< launcher-for-lisa (managed)"

repo_url="$DEFAULT_REPO_URL"
logins_src=""

step_no=0
declare -a CHANGES=()
declare -a WARNINGS=()
failed=0

usage() {
  cat <<'USAGE'
Usage: sudo setup/create-account.sh --logins <file> [--repo <git-url>]

Creates and configures the "lisa" account on this Omarchy machine.

  --logins <file>   Required. Local file with the decoded login links, one
                    "<id><TAB><url>" per line ("#" comments allowed). Installed
                    to /home/lisa/.config/lisa-launcher/logins, mode 600.
                    Its contents are never printed.
  --repo <git-url>  Git URL to clone into
                    /home/lisa/.local/share/launcher-for-lisa.
                    Default: https://github.com/vlebedev/launcher-for-lisa
  -h, --help        This text.

Idempotent: re-running only fills in what is missing.
USAGE
}

step() {
  step_no=$((step_no + 1))
  printf '\n\033[1;36m[%2d] %s\033[0m\n' "$step_no" "$*"
}

info() { printf '     %s\n' "$*"; }
changed() {
  printf '     \033[32m+ %s\033[0m\n' "$*"
  CHANGES+=("$*")
}
skipped() { printf '     \033[2m· %s\033[0m\n' "$*"; }
warn() {
  printf '     \033[33m! %s\033[0m\n' "$*" >&2
  WARNINGS+=("$*")
}
die() {
  printf '\033[31mError: %s\033[0m\n' "$*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

while (($#)); do
  case "$1" in
    --logins)
      [[ $# -ge 2 ]] || die "--logins needs a file argument"
      logins_src="$2"
      shift 2
      ;;
    --logins=*)
      logins_src="${1#--logins=}"
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || die "--repo needs a URL argument"
      repo_url="$2"
      shift 2
      ;;
    --repo=*)
      repo_url="${1#--repo=}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

if ((EUID != 0)); then
  die "must run as root — try: sudo $0 --logins <file>"
fi

[[ -n $logins_src ]] || {
  usage >&2
  die "--logins <file> is required"
}
[[ -f $logins_src ]] || die "logins file not found: $logins_src"
[[ -r $logins_src ]] || die "logins file not readable: $logins_src"

for tool in useradd passwd getent install jq git locale locale-gen sudo; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool missing: $tool"
done

printf '\033[1mlauncher-for-lisa — account setup\033[0m\n'
info "user:   $LISA_USER"
info "repo:   $repo_url"
info "logins: $logins_src (contents never printed)"

# ---------------------------------------------------------------------------
# Helpers that need the account to exist; filled in by step 1.
# ---------------------------------------------------------------------------

LISA_HOME=""
LISA_GROUP=""
REPO_DIR=""

# Run a command as lisa with a clean, session-free environment.
as_lisa() {
  sudo -u "$LISA_USER" -H -- \
    env -u XDG_RUNTIME_DIR -u DBUS_SESSION_BUS_ADDRESS -u XDG_SESSION_ID \
    HOME="$LISA_HOME" \
    "$@"
}

# lisa_dir <path> [mode] — ensure a directory exists, owned by lisa.
lisa_dir() {
  local path="$1" mode="${2:-755}"
  install -d -o "$LISA_USER" -g "$LISA_GROUP" -m "$mode" "$path"
}

# lisa_write <path> <mode> — write stdin to path, owned by lisa. Only replaces
# the file when the content actually differs, so re-runs stay quiet.
lisa_write() {
  local path="$1" mode="$2" tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [[ -f $path ]] && cmp -s "$tmp" "$path" &&
    [[ $(stat -c '%U:%a' "$path") == "$LISA_USER:$mode" ]]; then
    rm -f "$tmp"
    return 1
  fi
  install -o "$LISA_USER" -g "$LISA_GROUP" -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
  return 0
}

# ---------------------------------------------------------------------------
# 1. The account
# ---------------------------------------------------------------------------

step "Account '$LISA_USER'"

if getent passwd "$LISA_USER" >/dev/null; then
  skipped "already exists"
else
  useradd -m -c "$LISA_GECOS" -s "$LISA_SHELL" "$LISA_USER"
  changed "created user '$LISA_USER' (home seeded from /etc/skel)"
fi

LISA_HOME="$(getent passwd "$LISA_USER" | cut -d: -f6)"
LISA_GROUP="$(id -gn "$LISA_USER")"
REPO_DIR="$LISA_HOME/.local/share/launcher-for-lisa"

[[ -n $LISA_HOME && -d $LISA_HOME ]] || die "home directory for $LISA_USER not found"
info "home:  $LISA_HOME (group $LISA_GROUP)"

# No extra groups by design: logind grants seat access, and she must not have
# sudo. Just report it if a previous run or a human added her to wheel.
if id -nG "$LISA_USER" | tr ' ' '\n' | grep -qx "wheel"; then
  warn "$LISA_USER is in the 'wheel' group — the design says no sudo. Remove with: gpasswd -d $LISA_USER wheel"
else
  skipped "not in 'wheel' (no sudo), as designed"
fi

# ---------------------------------------------------------------------------
# 2. Password
# ---------------------------------------------------------------------------

step "Password"

pw_status="$(passwd -S "$LISA_USER" 2>/dev/null | awk '{print $2}' || true)"
if [[ $pw_status == "P" ]]; then
  skipped "a password is already set"
elif [[ ! -t 0 ]]; then
  warn "no password set and no terminal to ask on — run: sudo passwd $LISA_USER"
else
  info "setting a password for $LISA_USER (she will type this at the SDDM greeter)"
  if passwd "$LISA_USER"; then
    changed "set the login password for '$LISA_USER'"
  else
    warn "passwd failed — run 'sudo passwd $LISA_USER' by hand"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Locale de_CH.UTF-8
# ---------------------------------------------------------------------------

step "Locale $TARGET_LOCALE"

locale_generated() {
  # locale -a normalizes: "de_CH.UTF-8" is listed as "de_CH.utf8".
  local want
  want="$(printf '%s' "$TARGET_LOCALE" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
  locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' | grep -qx "$want"
}

if locale_generated; then
  skipped "$TARGET_LOCALE is already generated"
else
  if [[ ! -f /etc/locale.gen ]]; then
    warn "/etc/locale.gen missing — cannot generate $TARGET_LOCALE"
  else
    # The shipped line is "#de_CH.UTF-8 UTF-8" (with trailing whitespace).
    if grep -Eq '^[[:space:]]*de_CH\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
      skipped "/etc/locale.gen already enables $TARGET_LOCALE"
    elif grep -Eq '^[[:space:]]*#[[:space:]]*de_CH\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
      cp -a /etc/locale.gen "/etc/locale.gen.lisa-backup.$(date +%Y%m%d%H%M%S)"
      sed -i -E 's/^[[:space:]]*#[[:space:]]*(de_CH\.UTF-8[[:space:]]+UTF-8)/\1/' /etc/locale.gen
      changed "uncommented '$TARGET_LOCALE UTF-8' in /etc/locale.gen (backup alongside)"
    else
      printf '%s UTF-8\n' "$TARGET_LOCALE" >>/etc/locale.gen
      changed "appended '$TARGET_LOCALE UTF-8' to /etc/locale.gen"
    fi

    info "running locale-gen (this regenerates every enabled locale)…"
    locale-gen
    if locale_generated; then
      changed "generated $TARGET_LOCALE"
    else
      warn "locale-gen ran but $TARGET_LOCALE still is not listed by 'locale -a'"
      failed=1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4. Session language
# ---------------------------------------------------------------------------

step "Session language LANG=$TARGET_LOCALE"

lisa_dir "$LISA_HOME/.config" 755
lisa_dir "$LISA_HOME/.config/uwsm" 755
lisa_dir "$LISA_HOME/.config/uwsm/env.d" 755
lisa_dir "$LISA_HOME/.config/environment.d" 755

# (a) uwsm environment preloader -> systemd user activation environment.
#     Reaches Hyprland and everything launched through uwsm-app.
if lisa_write "$LISA_HOME/.config/uwsm/env.d/50-lisa-locale" 644 <<EOF; then
# Managed by launcher-for-lisa (setup/create-account.sh). Safe to delete.
#
# Sourced by uwsm's environment preloader (/usr/lib/uwsm/prepare-env.sh), which
# exports the result into the systemd user manager's activation environment.
# From there it reaches Hyprland (wayland-wm@Hyprland.service) and every app
# started via uwsm-app, which is how the Omarchy menu launches things.
export LANG=$TARGET_LOCALE
EOF
  changed "wrote ~/.config/uwsm/env.d/50-lisa-locale (LANG=$TARGET_LOCALE)"
else
  # shellcheck disable=SC2088  # literal ~ is intentional: this is human-facing text
  skipped "~/.config/uwsm/env.d/50-lisa-locale already correct"
fi

# (b) systemd user manager itself. Belt and braces: covers every user unit even
#     if the session is ever started without uwsm.
if lisa_write "$LISA_HOME/.config/environment.d/50-lisa-locale.conf" 644 <<EOF; then
# Managed by launcher-for-lisa (setup/create-account.sh). Safe to delete.
# Read by the systemd user manager (man 5 environment.d); applies to every
# user unit, including the Hyprland session and uwsm-app children.
LANG=$TARGET_LOCALE
EOF
  changed "wrote ~/.config/environment.d/50-lisa-locale.conf (LANG=$TARGET_LOCALE)"
else
  # shellcheck disable=SC2088  # literal ~ is intentional: this is human-facing text
  skipped "~/.config/environment.d/50-lisa-locale.conf already correct"
fi

if ! locale_generated; then
  warn "LANG is set to $TARGET_LOCALE but that locale is not generated — apps will fall back to C"
fi

# ---------------------------------------------------------------------------
# 5. Keyboard layout
# ---------------------------------------------------------------------------

step "Keyboard layout kb_layout = \"$KB_LAYOUT\""

input_lua="$LISA_HOME/.config/hypr/input.lua"
lisa_dir "$LISA_HOME/.config/hypr" 755

if [[ ! -f $input_lua ]]; then
  if [[ -f /etc/skel/.config/hypr/input.lua ]]; then
    install -o "$LISA_USER" -g "$LISA_GROUP" -m 644 \
      /etc/skel/.config/hypr/input.lua "$input_lua"
    changed "seeded ~/.config/hypr/input.lua from /etc/skel"
  else
    : >"$input_lua"
    chown "$LISA_USER:$LISA_GROUP" "$input_lua"
    chmod 644 "$input_lua"
    changed "created an empty ~/.config/hypr/input.lua"
  fi
fi

input_tmp="$(mktemp)"
# Drop any previous managed block, then append a fresh one.
awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
  $0 == b { skip = 1; next }
  $0 == e { skip = 0; next }
  !skip   { print }
' "$input_lua" >"$input_tmp"

# Warn about any *active* kb_layout outside our block: ours is appended last and
# therefore wins, but the owner should know the file disagrees with itself.
if grep -Eq '^[[:space:]]*kb_layout[[:space:]]*=' "$input_tmp"; then
  warn "$input_lua has another uncommented kb_layout; our appended block overrides it, but consider cleaning it up"
fi

# Collapse trailing blank lines so re-runs do not grow the file.
while [[ -s $input_tmp ]] && [[ -z $(tail -n 1 "$input_tmp") ]]; do
  sed -i '$d' "$input_tmp"
done

{
  printf '\n%s\n' "$BLOCK_BEGIN"
  cat <<EOF
-- Swiss German only. Appended last on purpose: Omarchy loads
-- default/hypr/input.lua first (via require("default.hypr.omarchy")), then this
-- file, and hl.config() overrides just the keys it names.
-- kb_variant is pinned to "" so a variant inherited from /etc/vconsole.conf
-- cannot be paired with the "$KB_LAYOUT" layout.
hl.config({
  input = {
    kb_layout = "$KB_LAYOUT",
    kb_variant = "",
  },
})
EOF
  printf '%s\n' "$BLOCK_END"
} >>"$input_tmp"

if cmp -s "$input_tmp" "$input_lua"; then
  # shellcheck disable=SC2088  # literal ~ is intentional: this is human-facing text
  skipped "~/.config/hypr/input.lua already sets kb_layout = \"$KB_LAYOUT\""
  rm -f "$input_tmp"
else
  install -o "$LISA_USER" -g "$LISA_GROUP" -m 644 "$input_tmp" "$input_lua"
  rm -f "$input_tmp"
  changed "set kb_layout = \"$KB_LAYOUT\" in ~/.config/hypr/input.lua"
fi

# ---------------------------------------------------------------------------
# 6. Idle timeouts
# ---------------------------------------------------------------------------

step "Idle timeouts (screensaver ${IDLE_SCREENSAVER}s, lock ${IDLE_LOCK}s)"

shell_json="$LISA_HOME/.config/omarchy/shell.json"
lisa_dir "$LISA_HOME/.config/omarchy" 755

if [[ ! -s $shell_json ]]; then
  if [[ -s /etc/skel/.config/omarchy/shell.json ]]; then
    install -o "$LISA_USER" -g "$LISA_GROUP" -m 644 \
      /etc/skel/.config/omarchy/shell.json "$shell_json"
    changed "seeded ~/.config/omarchy/shell.json from /etc/skel"
  else
    if lisa_write "$shell_json" 644 <<<'{"version":1,"idle":{}}'; then
      changed "created a minimal ~/.config/omarchy/shell.json"
    fi
  fi
fi

if ! jq -e . "$shell_json" >/dev/null 2>&1; then
  warn "$shell_json is not valid JSON — leaving it alone; fix it and re-run"
  failed=1
elif [[ $(jq -r '(.idle.screensaver // "") | tostring' "$shell_json") == "$IDLE_SCREENSAVER" ]] &&
  [[ $(jq -r '(.idle.lock // "") | tostring' "$shell_json") == "$IDLE_LOCK" ]]; then
  skipped "idle timeouts already correct"
else
  shell_tmp="$(mktemp)"
  jq --argjson s "$IDLE_SCREENSAVER" --argjson l "$IDLE_LOCK" \
    '.idle = ((.idle // {}) | .screensaver = $s | .lock = $l)' \
    "$shell_json" >"$shell_tmp"
  install -o "$LISA_USER" -g "$LISA_GROUP" -m 644 "$shell_tmp" "$shell_json"
  rm -f "$shell_tmp"
  changed "set idle.screensaver=$IDLE_SCREENSAVER, idle.lock=$IDLE_LOCK in ~/.config/omarchy/shell.json"
fi

# ---------------------------------------------------------------------------
# 7. SDDM autologin
# ---------------------------------------------------------------------------

step "SDDM autologin"

autologin_note="nothing to restore (no autologin.conf was present)"

if [[ -f $SDDM_AUTOLOGIN ]]; then
  target="$SDDM_AUTOLOGIN_DISABLED"
  if [[ -e $target ]]; then
    target="$SDDM_AUTOLOGIN_DISABLED.$(date +%Y%m%d%H%M%S)"
    warn "$SDDM_AUTOLOGIN_DISABLED already exists; backing up to $target instead"
  fi
  mv -- "$SDDM_AUTOLOGIN" "$target"
  changed "moved $SDDM_AUTOLOGIN -> $target (SDDM will now show the login screen)"
  autologin_note="sudo mv $target $SDDM_AUTOLOGIN   # then reboot or: systemctl restart sddm"
elif [[ -f $SDDM_AUTOLOGIN_DISABLED ]]; then
  skipped "already disabled ($SDDM_AUTOLOGIN_DISABLED is in place)"
  autologin_note="sudo mv $SDDM_AUTOLOGIN_DISABLED $SDDM_AUTOLOGIN   # then reboot or: systemctl restart sddm"
else
  skipped "no $SDDM_AUTOLOGIN found"
fi

# ---------------------------------------------------------------------------
# 8. Repository
# ---------------------------------------------------------------------------

step "Repository -> $REPO_DIR"

lisa_dir "$LISA_HOME/.local" 755
lisa_dir "$LISA_HOME/.local/share" 755

if [[ -d $REPO_DIR/.git ]]; then
  info "already cloned; fast-forwarding"
  if as_lisa git -C "$REPO_DIR" pull --ff-only; then
    skipped "repository up to date"
  else
    warn "git pull failed (offline? diverged?) — using the existing checkout as-is"
  fi
elif [[ -e $REPO_DIR ]]; then
  die "$REPO_DIR exists but is not a git checkout — move it aside and re-run"
else
  as_lisa git clone -- "$repo_url" "$REPO_DIR"
  changed "cloned $repo_url to $REPO_DIR"
fi

# ---------------------------------------------------------------------------
# 9. Logins file
# ---------------------------------------------------------------------------

step "Logins file"

logins_dst="$LISA_HOME/.config/lisa-launcher/logins"
lisa_dir "$LISA_HOME/.config/lisa-launcher" 700

# Count entries only. The contents (ids and URLs) are never printed.
logins_count="$(grep -cEv '^[[:space:]]*(#|$)' -- "$logins_src" || true)"

if [[ -f $logins_dst ]] && cmp -s "$logins_src" "$logins_dst"; then
  # Same content: just re-assert owner and mode (never install a file onto itself).
  chown "$LISA_USER:$LISA_GROUP" -- "$logins_dst"
  chmod 600 -- "$logins_dst"
  skipped "already installed, unchanged ($logins_count entries)"
else
  install -o "$LISA_USER" -g "$LISA_GROUP" -m 600 "$logins_src" "$logins_dst"
  changed "installed $logins_count login entries to ~/.config/lisa-launcher/logins (mode 600)"
fi

# ---------------------------------------------------------------------------
# 10. lisa-launcher install
# ---------------------------------------------------------------------------

step "lisa-launcher install"

launcher="$REPO_DIR/bin/lisa-launcher"
if [[ ! -f $launcher ]]; then
  warn "$launcher not found in the checkout — skipping. Push bin/lisa-launcher, then re-run this script (or, as lisa, run it directly)."
  failed=1
else
  # Never chmod the checkout: a mode change would dirty the worktree and can
  # make the next `git pull --ff-only` refuse. Run it through bash instead.
  if [[ -x $launcher ]]; then
    launcher_cmd=("$launcher")
  else
    warn "$launcher is not executable in the checkout — running it via bash; commit it with mode 755"
    launcher_cmd=(bash -- "$launcher")
  fi
  if as_lisa "${launcher_cmd[@]}" install; then
    changed "ran '$launcher install' as $LISA_USER (menu extension, Hyprland rules, systemd timer, ~/.local/bin symlink)"
  else
    warn "'$launcher install' failed — re-run it as lisa once the problem is fixed"
    failed=1
  fi
fi

# ---------------------------------------------------------------------------
# 11. Omarchy first-run / migration guard  (see header note 4 for the rationale)
# ---------------------------------------------------------------------------

step "Omarchy provisioning guard"

info "first-run provisioning (omarchy-provision-first-run -> install/user/*.sh)"
info "does not rewrite hyprland.lua, input.lua, shell.json, the env files or the"
info "menu extension — verified against this Omarchy version. See header note 4."

migrations_state="$LISA_HOME/.local/state/omarchy/migrations"

# Expected to be a no-op here: /etc/skel ships a zero-byte marker for every
# migration Omarchy currently carries, so `useradd -m` already baselined this
# home. The baseline branch below is the fallback for an Omarchy build whose
# skel does not ship them.
if [[ ! -d $OMARCHY_MIGRATIONS_DIR ]]; then
  skipped "$OMARCHY_MIGRATIONS_DIR not present; nothing to baseline"
elif [[ -d $migrations_state ]]; then
  marker_count=$(find "$migrations_state" -maxdepth 1 -type f -name '*.sh' | wc -l)
  skipped "migration state already exists ($marker_count markers, normally seeded from /etc/skel) — left alone so genuinely new migrations still run"
else
  lisa_dir "$LISA_HOME/.local/state" 755
  lisa_dir "$LISA_HOME/.local/state/omarchy" 755
  lisa_dir "$migrations_state" 755
  count=0
  for migration in "$OMARCHY_MIGRATIONS_DIR"/*.sh; do
    [[ -f $migration ]] || continue
    marker="$migrations_state/$(basename -- "$migration")"
    : >"$marker"
    chown "$LISA_USER:$LISA_GROUP" "$marker"
    count=$((count + 1))
  done
  changed "no migration state (this Omarchy's /etc/skel ships none) — marked $count shipped migrations as already applied, the same baseline as 'omarchy-provision-user --first-install'"
fi

# ---------------------------------------------------------------------------
# Ownership sweep
# ---------------------------------------------------------------------------

step "Ownership of $LISA_HOME"

declare -a stray=()
mapfile -d '' -t stray < <(find "$LISA_HOME" \! -user "$LISA_USER" -print0 2>/dev/null || true)
if ((${#stray[@]} == 0)); then
  skipped "every file under $LISA_HOME is owned by $LISA_USER"
else
  for path in "${stray[@]}"; do
    chown -h "$LISA_USER:$LISA_GROUP" -- "$path"
  done
  changed "re-owned ${#stray[@]} path(s) under $LISA_HOME to $LISA_USER"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n\033[1m─── Summary ───────────────────────────────────────────────\033[0m\n'

if ((${#CHANGES[@]} == 0)); then
  printf '  Nothing changed — everything was already in place.\n'
else
  printf '  Changed:\n'
  for c in "${CHANGES[@]}"; do printf '    • %s\n' "$c"; done
fi

if ((${#WARNINGS[@]} > 0)); then
  printf '\n\033[33m  Warnings:\033[0m\n'
  for w in "${WARNINGS[@]}"; do printf '    ! %s\n' "$w"; done
fi

printf '\n  Restore autologin for the owner:\n    %s\n' "$autologin_note"

printf '\n  Next: reboot (or "systemctl restart sddm"), pick "%s" at the greeter\n' "$LISA_USER"
printf '  and log into the Omarchy session. Then check, in her session:\n'
# shellcheck disable=SC2016  # $LANG is a command for the reader to type, not an expansion
printf '    echo $LANG                # expect %s\n' "$TARGET_LOCALE"
printf '    hyprctl getoption input:kb_layout    # expect %s\n' "$KB_LAYOUT"
printf '    F1 (or brightness-down)   # expect the Lisa menu\n'

if ((failed)); then
  printf '\n\033[33m  One or more steps did not complete. Fix the warnings above and re-run.\033[0m\n'
  exit 1
fi

printf '\n\033[32m  Done.\033[0m\n'
