# gaming

Gaming stack — **desktop only** (imported from `hosts/desktop/default.nix`, never
from `base`, so the Intel laptops never pull the CachyOS kernel or AMD GPU stack).

| File         | Configures                                                        |
|--------------|------------------------------------------------------------------|
| `kernel.nix` | CachyOS kernel (`linuxPackages_cachyos`) + `scx` sched-ext scheduler, via chaotic-cx/nyx + its binary cache. |
| `steam.nix`  | Steam, gamescope, GE-Proton (declarative `extraCompatPackages`). |
| `gamemode.nix` | gamemode + its settings — the host's high-performance mode (governor, renice, AMD perf level). Needs `gamemoderun %command%` per game. |
| `gpu.nix`    | AMD GPU: RADV/mesa, LACT (`lactd`), MangoHud overlay, `ppfeaturemask` overdrive unlock. |
| `controller.nix` | Xbox One/Series controller over Bluetooth: `xpadneo` driver + `disable_ertm` modprobe fix. |
