## Artix dinit labwc minimal config

## Ly

I had to change `/etc/dinit.c/config/console.conf` to free a console for ly-dm

```
ACTIVE_CONSOLES="/dev/tty[2-6]"
```
