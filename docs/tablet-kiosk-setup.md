# Tablet Kiosk Setup

Ubuntu tablet uses `rtcwake` to sleep/wake on a schedule and auto-launches the dashboard in Firefox on wake via Tailscale.

## How it works

- A cron job runs `rtcwake -m mem` at 9PM nightly, sleeping for 9 hours
- On wake/boot, a desktop autostart entry launches Firefox pointing at the Tailscale IP
- Automatic suspend is disabled so the tablet stays awake until rtcwake triggers

## Key files

**Autostart entry:**

```
~/.config/autostart/kiosk.desktop
```

**Cron (root):**

```bash
sudo crontab -e
# 0 21 * * * /usr/sbin/rtcwake -m mem -s 32400
```

## To edit

```bash
nano ~/.config/autostart/kiosk.desktop
```

## Disable automatic sleep

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 0
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```
