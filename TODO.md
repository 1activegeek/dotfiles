
Reference Project: ../bootstrap-mac-os
Ignore the dotfiles folder in this repo, it is basically a copy of this repo. 

Build around Chezmoi for everything - use advanced capabilities to run scripts for installers
Read the documentation and reference the documentation for all errors, issues and best practices for usage: https://www.chezmoi.io 
Need to create a process for homebrew to constantly export out a copy of the current brewfile state every X period
Output 3 main single liner options that can be run on a machine at any time (in the Readme.md):
- Setup a brand new device - deploys all apps, starts with key/core apps first for usability, then deploys secondary apps and syncs dotfiles before launching apps (so that 85% of our configuration is complete). Lastly it will output a checklist of FUP items for the user to remember to deploy/configure.
- Sync a current device (apps+dotfiles) - this should take the same kind of approach as number one, but in the Homebrew side of things, will REMOVE apps that are NOT contained in a brewfile of the current apps or a list of the current apps. Will install apps that are missing from the brewfile. This should cover both homebrew, and MAS. 
- Sync a current device (dotfiles only) - as the name implies, basically just running standard chezmoi for dotfile syncing
Additional reminders in the Readme for the core commands I would need to run as I add/remove things from my config
Want to also consider using the auto-sync option that can automatically add to the chezmoi configs rather than requiring manual updates
Ideal state for things like Homebrew and MAS apps - is a single file I that can be updated regularly kept in alphabetical order for simplicity.
Readme File should explains in plain english what gets laid down for each use case, added details above, and just a general friendly explainer for anyone visiting the repo. Keep it brief overall. 
ANY secrets, passwords, keys, etc - are to be stored in 1Password. Nothing secret or sensitive get's stored to the repo. Some things can also be runtime added - such as name/email for GH setup, using the template file syntax.
I also need to add a template file that can be used to REMOVE certain apps from being installed on my work machines (for example, no office apps). Will need some help desiging or appropriately configuring what is avoided here.
U/se native application functionality where possible to keep everything dependency free. We should only be utilizing Chezmoi, 1Password CLI, github, MAS, and ZSH native functions where possible. It may be beneficial to build out a second phase later where this can be adapted for a Windows based machine, but that is far off. 
The contents in the bootstrap repo should be used as a starter and cover MOST of the necessary apps to be configured or added in.
Additionally, some dotfiles I need to ADD to this repo:
~/.config/1Password/*
~/.config/atuin/*
~/.config/gh/config.yml
~/.config/ghostty/*
~/.config/keyboardcowboy/*
~/.config/leaderkey/*
~/.config/sops/* (this contains secrets, so sync with 1Password only, and use templates to replace locally only)
~/.config/zellij/*
~/.config/zoxide/*
~/.ssh/config (should be stored in 1Password)
~/.ssh/

LAstly something else we need to do, is identify the best way to install all the skills, commands, agents, etc that we watn to use for various AI CLIs, in a .agents folder, andh ave that properly linked for each of the various agents (.opencode .claude .codex) etc so that that those subfolders in those dotfile locations can be synced. This one might require external tooling ot add in here, but the goal is it should ease the burden of installing these toolings in various places, I'd rather just as simple as a symlink for exmaple from .claude/skills -> .agents/skills. We need to be aware of formatting issues between agents though. Let me know if this one is too difficult to do in the initila pass and we can do this later. 

# 2026-03-08 Updates
- Need to run appcleaner to enable autoclean setting
- 