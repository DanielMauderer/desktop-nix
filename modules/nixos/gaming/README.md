# gaming

Gaming stack — **desktop only** (imported from `hosts/desktop/default.nix`, never
from `base`, so the Intel laptops never pull the CachyOS kernel or AMD GPU stack).

| File         | Configures                                                        |
|--------------|------------------------------------------------------------------|
| `kernel.nix` | CachyOS kernel (`linuxPackages_cachyos`) + `scx` sched-ext scheduler, via chaotic-cx/nyx + its binary cache. |
| `steam.nix`  | Steam, gamemode, gamescope, GE-Proton (declarative `extraCompatPackages`). |
| `gpu.nix`    | AMD GPU: RADV/mesa, LACT (`lactd`), MangoHud overlay.            |
