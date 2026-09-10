# Launcher for Lisa

## What it is

A one-key menu of Lisa's school websites on her Omarchy/Hyprland laptop.
Pressing F1 (or the brightness-down key) opens a native Omarchy menu; picking a
row opens that site as a Chromium app window on its own fixed workspace.
It is a convenience only: the full Omarchy desktop stays available and nothing
is locked down.

## How it works

- **Menu.** `lisa-launcher install` generates
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` from `sites.json`: a
  submenu `lisa` (alias `lisa`) with one row per site whose action is
  `lisa-launcher open <id>`. The F1 / brightness-down binds in
  `~/.config/hypr/lisa-launcher.lua` run `lisa-launcher menu`, which is
  `omarchy-menu toggle lisa`. Escape closes; the key again toggles.
  The `lisa` row also shows up in the root SUPER+SPACE menu, which is fine.
- **Workspaces.** Each site has a `workspace` number in `sites.json`
  (workspace 1 stays empty as "home"). `install` writes one Hyprland window
  rule per site matching the Chromium app-window class
  `chrome-<host>__-Default`, so the window lands on its workspace on spawn.
- **Focus if running.** `lisa-launcher open <id>` calls
  `omarchy-launch-or-focus-webapp` with a class pattern unique to that site.
  If the window already exists it is focused (Hyprland switches workspace);
  otherwise Chromium starts with `--app=URL` (no address bar).
- **Self-update.** A systemd user timer (`lisa-launcher-update.timer`) runs
  `lisa-launcher update` about 2 minutes after each login and then hourly.
  It does `git pull --ff-only` in the clone and, if HEAD moved, re-runs
  `install`. Network failures are silent. `lisa-launcher update --force`
  re-runs `install` even without new commits.

Sessions live in Chromium cookies; the launcher only ever opens plain URLs.

## Adding or changing a site

1. Edit `sites.json` (ordered array of `{id, label, glyph, url, workspace}`;
   `glyph` is a Nerd Font glyph, `workspace` a free number greater than 1).
2. `git commit` and `git push`.
3. It lands on her machine within an hour, or about 2 minutes after her next
   login. To apply immediately, run `lisa-launcher update --force` as lisa.

`lisa-launcher list` prints the current table (id, label, workspace, url).

## Re-login after a session expiry

As lisa: `lisa-launcher login <id>`. This opens the site's private login link
in the same Chromium profile, so the new cookies are picked up by the normal
menu entry. `lisa-launcher login` with no argument lists the ids available.

The links live in `~/.config/lisa-launcher/logins` (mode 600, never committed).
Format: one `<id><TAB><url>` per line, `#` lines are comments, e.g.

    # id	url
    klett	https://...
    anton	https://...

The owner's copy of that file is under `private/` in this repo (gitignored).
If the file is missing an id, the command says so; no repo change is needed.

## Setting up a new machine

1. Install Omarchy and log in once as the owner.
2. From this repo: `sudo setup/create-account.sh --logins <file>`
   (optional `--repo <git url>`, default is this repo on GitHub).

The script is idempotent and prints each step: creates user `lisa` (no sudo,
no extra groups), asks for a password if none, enables the `de_CH.UTF-8`
locale and sets it as her session language, sets Swiss German keyboard
layout, sets idle screensaver 10 min / lock 60 min, disables SDDM autologin,
clones the repo to `~/.local/share/launcher-for-lisa`, installs the logins
file, runs `lisa-launcher install` as lisa, and sets up the migration path
described below. Omarchy finishes provisioning her account on her first
Hyprland login; test the menu manually after that.

## Omarchy updates and Lisa's account

You update Omarchy from your own account as usual. Afterwards Lisa's session
shows the standard "Pending Omarchy Migrations" notification. Clicking it, or
running `omarchy-migrate` in her terminal, applies the migrations even though
she has no sudo: `~/.local/bin/omarchy-migrate` is a shim that calls
`/usr/local/sbin/lisa-omarchy-migrate` through a sudoers rule limited to that
one script. The wrapper runs the real `omarchy-migrate` as root with her home
and session environment, then re-owns anything root left in `/home/lisa`.
`omarchy-migrate --pending` stays a plain read-only call.

Check it from her session with `command -v omarchy-migrate` (expect the shim
path) or from yours with `sudo /usr/local/sbin/lisa-omarchy-migrate --dry-run`.

## The login screen

Omarchy's own SDDM theme is a password box that always logs in the last user;
it has no way to choose an account. The setup script therefore installs a
variant, `omarchy-lisa`, to `/usr/share/sddm/themes/omarchy-lisa` and selects
it with `/etc/sddm.conf.d/99-zz-lisa-theme.conf`. It looks the same but shows
the account names above the password box. Left/Right, Tab, or a click switch
the account; Enter logs in. The last user logged in is preselected. Delete
the drop-in file to return to Omarchy's theme.

## Restoring owner autologin

The setup script moves `/etc/sddm.conf.d/autologin.conf` to
`/etc/sddm-autologin.conf.disabled`, outside the directory. It has to be
outside: SDDM reads every file in `/etc/sddm.conf.d/` whatever its name, so a
backup left in there keeps autologin active. Move it back to restore:

    sudo mv /etc/sddm-autologin.conf.disabled /etc/sddm.conf.d/autologin.conf

## Things the setup script fixes for a no-sudo account

- **"Wayland Diagnose" notification from Fcitx.** Omarchy runs the Fcitx5
  input-method daemon in every session. Its Wayland module tries to push its
  own keyboard layout to the compositor and, failing that on Hyprland, shows
  a notification. The script turns that override off, gives Fcitx a profile
  matching the Swiss German layout, and hides that notification id.
- **Superuser prompt on theme changes.** Every theme change runs
  `omarchy-theme-set-browser-policy` through sudo. Omarchy grants that to
  `wheel` only, so a non-wheel account got a password prompt. The script adds
  the same passwordless grant for `lisa` to `/etc/sudoers.d/lisa-omarchy-migrate`.

## Known trade-offs

- **Brightness-down key is taken in Lisa's account.** On this Apple keyboard a
  bare F1 press sends `XF86MonBrightnessDown`, so the launcher binds it too and
  overrides Omarchy's "brightness down". Fn+F1 sends plain `F1` (also bound).
  Omarchy's `SHIFT+` and `ALT+` brightness-down variants are untouched, and
  brightness-up still works. Only Lisa's account is affected.
- **The menu extension file is overwritten.** `install` rewrites
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` entirely every time. Any
  hand edits in Lisa's copy are lost on the next update; put extra menu rows
  into `sites.json` or accept the loss.
- Adding a site requires a push; there is no on-device editor by design.

## File map

    sites.json                          site list, the single source of truth
    bin/lisa-launcher                   bash CLI: install | menu | open <id> |
                                        login [<id>] | update [--force] | list | help
    systemd/lisa-launcher-update.*      user timer + oneshot service for self-update
    setup/create-account.sh             one-off root script for a new machine
    setup/sddm-theme/omarchy-lisa/      SDDM greeter theme with a user switcher
    setup/lisa-omarchy-migrate          root wrapper installed to /usr/local/sbin
    setup/omarchy-migrate-shim          installed as ~/.local/bin/omarchy-migrate
    docs/design.md                      the design contract; docs/idea.txt the origin
    private/                            gitignored, owner's local copy of login links

On Lisa's machine: repo at `~/.local/share/launcher-for-lisa`, CLI symlinked
to `~/.local/bin/lisa-launcher`, generated config in
`~/.config/hypr/lisa-launcher.lua` (required from `hyprland.lua`),
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, and units in
`~/.config/systemd/user/`.
