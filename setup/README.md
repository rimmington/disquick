Nix and Disnix setup for Debian
===============================

Not idempotent.

Builds Nix from source so this will work non-x86 archs.
On ARM machines, adds `nixos-arm.dezgeg.me` as a binary cache.

On a RAM-constrained machine like a Raspberry Pi, you may need to set up additional swap space for the build; 2GB total memory should be safe.

```
sudo ./nix.sh $USER
sudo ./disnix.sh $USER
```
