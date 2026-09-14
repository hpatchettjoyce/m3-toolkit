# Branding assets

Drop the brand assets here before starting Chunk 6 of `UPGRADE_PLAN.md`.

## Where this folder is, from Windows

Paste into the Windows Explorer address bar:

```
\\wsl.localhost\Ubuntu\home\harvey\projects\m3-toolkit\assets\branding
```

On older Windows builds the prefix is `\\wsl$\Ubuntu\...` instead. The repo root is
`\\wsl.localhost\Ubuntu\home\harvey\projects\m3-toolkit` — worth pinning to Quick Access.

## What to put here

- `M3 Branding Guide.pdf` — from
  `G:\My Drive\05_GAME DESIGN CONCEPTS\Monumentum\03_Visual Assets\`
- Logo PNGs — full lockup, mark/icon only, and a light-on-dark variant if one exists.

Chunk 6 needs the PDF (palette). Chunk 7 needs the PNGs.

## Why they can't be read from Drive directly

`G:` isn't mounted in this WSL environment — only `/mnt/c` exists. To mount it instead of
copying files in:

```bash
sudo mkdir -p /mnt/g
sudo mount -t drvfs G: /mnt/g
```

Add it to `/etc/fstab` to persist across reboots. Optional — copying the files in is enough.
