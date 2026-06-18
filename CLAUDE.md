# Claude Code — agent guidance for this repo

Declarative NixOS config for four hosts. home-manager runs as a NixOS module.
The Nix code is the source of truth; the docs are kept deliberately small.

## Where things live

```
hosts/<name>/default.nix   per-host config: imports modules, sets host options
hosts/<name>/README.md     what the machine is (role, hardware, modules)
hosts/<name>/INSTALL.md    how to install it
modules/nixos/<group>/     system modules — each group dir has a README.md
modules/home/<group>/      home-manager modules — each group dir has a README.md
lib/mkHost.nix             nixosConfiguration factory (name, modules, withChaotic)
flake.nix                  inputs/outputs + per-host nixosTests/assertions
docs/DECISIONS.md          short list of the key architecture choices
```

## Testing

CI builds every host and runs the nixosTests on each push. Before pushing, run
what CI runs:

```sh
nix develop                 # lint/format tools
nix flake check -L          # eval + per-host build + nixosTests
nix fmt                     # format all .nix files
```

## Documentation convention

Keep docs short and close to the code:

- Each **host** has a `README.md` (description) and an `INSTALL.md` (install
  guide). Update them when the host's modules, hardware, or install flow change.
- Each **module group** (`modules/nixos/*`, `modules/home/*`) has a short
  `README.md` listing what its `.nix` files configure. Update it when you add or
  remove a file in that group.
- Record genuinely new architecture choices in `docs/DECISIONS.md` (one line).
  Don't reintroduce per-ticket status docs, roadmaps, or audit reports.
