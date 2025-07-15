#!/bin/bash

# ==============================================================================
#
#          FILE: setup.sh
#
#         USAGE: sudo ./setup.sh
#
#   DESCRIPTION: A script to set up a new Debian/Linux device.
#                This script is designed to be idempotent and updatable,
#                meaning it can be run multiple times without causing issues.
#
# ==============================================================================

# --- SCRIPT START ---

# Exit immediately if a command exits with a non-zero status.
set -e

# --- CHECK FOR ROOT ---
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Please run it with 'sudo ./setup.sh'"
    exit 1
fi

# --- USER CREATION ---
echo "--- Checking for user 'saveli' ---"
if ! id "saveli" &>/dev/null; then
    echo "User 'saveli' not found. Creating user..."
    useradd -m saveli
    echo "Please create a password for the new user 'saveli':"
    passwd saveli
else
    echo "User 'saveli' already exists. Skipping user creation."
fi
echo "--- User check complete ---"
echo

# --- SUDO INSTALLATION ---
echo "--- Checking for 'sudo' package ---"
if ! dpkg -s sudo &>/dev/null; then
    echo "The 'sudo' package is not installed. Installing..."
    apt-get update
    apt-get install -y sudo
    echo "'sudo' has been installed."
else
    echo "The 'sudo' package is already installed."
fi
echo "--- Sudo check complete ---"
echo

# --- ADD USER TO SUDO GROUP ---
echo "--- Adding 'saveli' to 'sudo' group ---"
if ! groups saveli | grep -q '\bsudo\b'; then
    echo "Adding user 'saveli' to the 'sudo' group..."
    usermod -aG sudo saveli
    echo "User 'saveli' has been added to the 'sudo' group."
else
    echo "User 'saveli' is already in the 'sudo' group."
fi
echo "--- Sudo group check complete ---"
echo

# --- APT PACKAGE INSTALLATION ---
# build-essential is required for Homebrew
DEV_PACKAGES="git wget curl vim neovim zsh i3 jq x11-xserver-utils gpg firefox-esr openssh-client openssh-server build-essential"
echo "--- Installing APT packages ---"
apt-get update
for pkg in $DEV_PACKAGES; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        apt-get install -y "$pkg"
    else
        echo "$pkg is already installed."
    fi
done
echo "--- APT packages installation complete ---"
echo

# --- RUST INSTALLATION ---
echo "--- Installing Rust (rustup) ---"
if ! sudo -u saveli -i bash -c 'command -v cargo' &>/dev/null; then
    echo "Rust is not installed. Installing via rustup..."
    # The rustup script correctly modifies the user's .profile
    sudo -u saveli bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    echo "Rust has been installed."
else
    echo "Rust (cargo) is already installed."
fi
echo "--- Rust installation check complete ---"
echo

# --- HOMEBREW INSTALLATION (THE CORRECT WAY) ---
echo "--- Installing Homebrew to /home/linuxbrew/.linuxbrew ---"
HOMEBREW_DIR="/home/linuxbrew/.linuxbrew"
if [ ! -d "$HOMEBREW_DIR" ]; then
    echo "Homebrew not found. Installing..."
    # Create the directory and install as root
    mkdir -p "$HOMEBREW_DIR"
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "$HOMEBREW_DIR"
    
    # Set ownership for the 'saveli' user
    echo "Setting ownership of Homebrew installation to 'saveli'..."
    chown -R saveli:saveli /home/linuxbrew
    
    echo "Homebrew files have been installed."
else
    echo "Homebrew is already installed."
fi

# --- CONFIGURE SHELL FOR HOMEBREW (THE CRITICAL STEP) ---
echo "--- Adding Homebrew to user's shell environments ---"
PROFILE_FILE="/home/saveli/.profile"
ZSHRC_FILE="/home/saveli/.zshrc"
BREW_INIT_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

# Configure .profile (for login shells, used by `sudo -i`)
if ! sudo -u saveli grep -qF "$BREW_INIT_LINE" "$PROFILE_FILE"; then
    echo "Adding Homebrew to .profile..."
    echo -e "\n# Add Homebrew to PATH\n$BREW_INIT_LINE" | sudo -u saveli tee -a "$PROFILE_FILE" > /dev/null
fi

# Configure .zshrc (for interactive Zsh shells)
sudo -u saveli touch "$ZSHRC_FILE"
if ! sudo -u saveli grep -qF "$BREW_INIT_LINE" "$ZSHRC_FILE"; then
    echo "Adding Homebrew to .zshrc..."
    echo -e "\n# Add Homebrew to PATH\n$BREW_INIT_LINE" | sudo -u saveli tee -a "$ZSHRC_FILE" > /dev/null
fi
echo "--- Homebrew shell configuration complete ---"
echo

# --- BREW TOOL INSTALLATION ---
BREW_PACKAGES="git-delta bat fzf exa zoxide ripgrep"
echo "--- Installing Homebrew tools ---"
for pkg in $BREW_PACKAGES; do
    # Run brew commands within a login shell (-i) to ensure the environment from .profile is loaded.
    if ! sudo -u saveli -i bash -c "brew list '$pkg'" &>/dev/null; then
        echo "Installing $pkg with Homebrew..."
        sudo -u saveli -i bash -c "HOMEBREW_NO_AUTO_UPDATE=1 brew install '$pkg'"
    else
        echo "$pkg is already installed."
    fi
done
echo "--- Homebrew tools installation complete ---"
echo

# --- GIT DELTA CONFIGURATION ---
echo "--- Configuring Git to use git-delta ---"
if [[ "$(sudo -u saveli git config --global core.pager)" != "delta" ]]; then
    echo "Setting git-delta as the core.pager for Git..."
    sudo -u saveli git config --global core.pager "delta"
else
    echo "git-delta is already set as the core.pager."
fi
if [[ "$(sudo -u saveli git config --global interactive.diffFilter)" != "delta --color-only" ]]; then
    echo "Setting git-delta as the interactive.diffFilter for Git..."
    sudo -u saveli git config --global interactive.diffFilter "delta --color-only"
else
    echo "git-delta is already set as the interactive.diffFilter."
fi
echo "--- Git Delta configuration complete ---"
echo

# --- SSH KEY GENERATION ---
echo "--- Checking for SSH key ---"
SSH_DIR="/home/saveli/.ssh"
SSH_KEY_FILE="${SSH_DIR}/id_ed25519"

if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "SSH key not found. Generating a new one..."
    sudo -u saveli mkdir -p "$SSH_DIR"
    sudo -u saveli chmod 700 "$SSH_DIR"
    sudo -u saveli ssh-keygen -t ed25519 -C "saveli.gulas@gmail.com" -N "" -f "$SSH_KEY_FILE"
    echo "SSH key generated successfully."
    echo
    echo "######################### YOUR PUBLIC SSH KEY #########################"
    sudo -u saveli cat "${SSH_KEY_FILE}.pub"
    echo "#####################################################################"
    echo
else
    echo "SSH key already exists. Skipping generation."
fi
echo "--- SSH key check complete ---"
echo

# --- OH MY ZSH & ZSH CONFIGURATION ---
echo "--- Installing Oh My Zsh ---"
if [ ! -d "/home/saveli/.oh-my-zsh" ]; then
    echo "Oh My Zsh not found. Installing..."
    sudo -u saveli sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) -s --unattended"
    echo "Oh My Zsh has been installed."
else
    echo "Oh My Zsh is already installed."
fi

echo "--- Installing Zsh theme and plugins ---"
ZSH_CUSTOM_DIR="/home/saveli/.oh-my-zsh/custom"
P10K_DIR="${ZSH_CUSTOM_DIR}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    echo "Installing Powerlevel10k theme..."
    sudo -u saveli git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    echo "Powerlevel10k theme is already installed."
fi
if [ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    sudo -u saveli git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions is already installed."
fi
if [ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    sudo -u saveli git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting is already installed."
fi

echo "--- Configuring Zsh theme and plugins in .zshrc ---"
NEW_THEME='ZSH_THEME="powerlevel10k/powerlevel10k"'
NEW_PLUGINS='plugins=(git complete-alias zsh-autosuggestions zsh-syntax-highlighting fzf docker colored-man-pages alias-finder command-not-found history)'
if ! sudo -u saveli grep -q '^ZSH_THEME="powerlevel10k/powerlevel10k"' "$ZSHRC_FILE"; then
    echo "Setting Powerlevel10k as the Zsh theme..."
    sudo -u saveli sed -i 's|^ZSH_THEME=.*|'"$NEW_THEME"'|' "$ZSHRC_FILE"
fi
if ! sudo -u saveli grep -q "plugins=(.*zsh-autosuggestions.*)" "$ZSHRC_FILE"; then
    echo "Setting the custom plugin list in .zshrc..."
    sudo -u saveli sed -i "s/^plugins=(.*)/${NEW_PLUGINS}/" "$ZSHRC_FILE"
fi

echo "--- Setting Zsh as default shell ---"
if [[ "$(getent passwd saveli | cut -d: -f7)" != "$(which zsh)" ]]; then
    echo "Setting Zsh as the default shell for 'saveli'..."
    chsh -s "$(which zsh)" saveli
fi
echo "--- Zsh & Oh My Zsh setup complete ---"
echo

# --- ZSH ALIAS CONFIGURATION ---
echo "--- Configuring Zsh aliases ---"
START_MARKER="# --- Custom Aliases ---"
END_MARKER="# --- End Custom Aliases ---"

ZSH_ALIASES_CONFIG=$(cat <<'EOF'

# --- Custom Aliases ---
# Disable the bell sound
unsetopt beep

# Keyboard layout
alias init_ch="setxkbmap ch de_nodeadkeys; echo \"changed keyboard layout to ch de_nodeadkeys\""

# Detached Applications
alias clion_d="nohup clion &> /dev/null &"
alias firefox_d="nohup firefox &> /dev/null &"

# Git Aliases
alias git_init_track='git init && echo "Initialized repo." && read -p "Remote URL: " url && git remote add origin "$url" && git fetch origin && branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@") && git checkout -b "$branch" --track "origin/$branch" && echo "Checked out tracking branch: $branch"'
alias git_log_last='git log -1 HEAD'
alias git_s='git add'
alias git_s_all='git add .'
alias git_s_undo='git restore --staged'
alias git_c='git commit -m'
alias git_u_diff='git diff HEAD'
alias git_s_diff='git diff --cached'
alias git_rao='git remote add origin'
alias git_pu_init='git push -u'
alias git_pu_init_o='git push -u origin'
alias git_pu='git push'
alias git_pu_o='git push origin'
alias git_pl='git pull'
alias git_pl_o='git pull origin'
alias git_br='git branch'
alias git_log_all='git log --oneline --graph --decorate --all'
alias git_diff='delta'
alias git_diff_all='git diff; for f in $(git ls-files --others --exclude-standard); do echo "--- $f ---"; git diff --no-index /dev/null "$f"; done'
alias git_s_mod='git add -u'
alias git_c_edit='git commit --amend'
alias git_log_graph='git log --oneline --graph --all --decorate'
alias git_log_commits='git log -n 10 --oneline'
alias git_log_file='git log --follow'
alias git_s_diff_upstream='git diff @{u}'
alias git_br_del='git branch -d'
alias git_br_del_rem='git push origin --delete'
alias git_br_remote='git branch -r'
alias git_st='git stash'
alias git_st_apply='git stash apply'
alias git_repo_reset='git reset --hard; git clean -fd'
alias git_br_rename='git branch -m'
alias git_undo='git reset --soft HEAD~1'
alias git_pu_lease='git push --force-with-lease'
alias git_br_cleanup='git fetch -p && git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

# GitHub CLI Aliases
alias gh_mr='gh pr create -f'
alias gh_mr_view='gh pr view --web'
alias gh_mr_co='gh pr checkout'
alias gh_fork='gh repo fork --clone'
alias gh_view='gh repo view --web'
# --- End Custom Aliases ---
EOF
)
# Remove the old alias block to ensure we can update it
sudo -u saveli sed -i "/^${START_MARKER}$/,/^${END_MARKER}$/d" "$ZSHRC_FILE"

# Append the fresh, updated alias block
echo "Updating/Adding custom alias block in .zshrc..."
echo "$ZSH_ALIASES_CONFIG" | sudo -u saveli tee -a "$ZSHRC_FILE" > /dev/null
echo "Custom aliases have been configured."
echo "--- Zsh alias configuration complete ---"
echo

# --- VIM CONFIGURATION ---
echo "--- Configuring Vim ---"
VIMRC_FILE="/home/saveli/.vimrc"
sudo -u saveli touch "$VIMRC_FILE"
VIM_CONFIG=$(cat <<'EOF'

" Replace audible bell with a visual flash
set visualbell

" Normal mode = block cursor
" Insert mode = vertical bar cursor
if exists('&t_SI')
  let &t_SI = "\e[6 q"
endif
if exists('&t_EI')
  let &t_EI = "\e[2 q"
endif
EOF
)
if ! grep -qF 'set visualbell' "$VIMRC_FILE"; then
    echo "Adding Vim configuration to .vimrc..."
    echo "$VIM_CONFIG" | sudo -u saveli tee -a "$VIMRC_FILE" > /dev/null
fi
echo "--- Vim configuration complete ---"
echo

# --- ALACRITTY INSTALLATION & CONFIGURATION ---
echo "--- Installing Alacritty ---"
if ! sudo -u saveli -i bash -c 'command -v alacritty' &>/dev/null; then
    echo "Alacritty not found. Installing from source..."
    apt-get install -y cmake pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev python3
    sudo -u saveli -i bash -c "cargo install alacritty"
    echo "Alacritty has been installed."
else
    echo "Alacritty is already installed."
fi

echo "--- Configuring Alacritty ---"
ALACRITTY_CONFIG_DIR="/home/saveli/.config/alacritty"
ALACRITTY_CONFIG_FILE="$ALACRITTY_CONFIG_DIR/alacritty.toml"

ALACRITTY_CONFIG=$(cat <<'EOF'
[env]
TERM = "xterm-256color"
[window]
opacity = 0.95
blur = true
padding = { x = 10, y = 10 }
decorations = "full"
startup_mode = "Windowed"
[font]
size = 12.0
[font.normal]
family = "JetBrains Mono"
style = "Regular"
[colors.primary]
background = "#2d1b69"
foreground = "#e2e2e2"
[colors.cursor]
text = "#2d1b69"
cursor = "#ff6ac1"
[colors.selection]
text = "#e2e2e2"
background = "#6441a5"
[colors.normal]
black = "#1a0d33"
red = "#ff5555"
green = "#50fa7b"
yellow = "#f1fa8c"
blue = "#8be9fd"
magenta = "#ff79c6"
cyan = "#9aedfe"
white = "#e2e2e2"
[colors.bright]
black = "#44475a"
red = "#ff6e6e"
green = "#69ff94"
yellow = "#ffffa5"
blue = "#d6acff"
magenta = "#ff92df"
cyan = "#a4ffff"
white = "#ffffff"
[[keyboard.bindings]]
key = "Period"
mods = "Control"
action = "IncreaseFontSize"
[[keyboard.bindings]]
key = "Minus"
mods = "Control"
action = "DecreaseFontSize"
[[keyboard.bindings]]
key = "Key0"
mods = "Control"
action = "ResetFontSize"
[cursor]
style = { shape = "Block", blinking = "On" }
EOF
)

echo "Writing new Alacritty configuration..."
sudo -u saveli mkdir -p "$ALACRITTY_CONFIG_DIR"
echo "$ALACRITTY_CONFIG" | sudo -u saveli tee "$ALACRITTY_CONFIG_FILE" > /dev/null
echo "Alacritty has been configured."
echo "--- Alacritty configuration complete ---"
echo

# --- I3 CONFIGURATION ---
echo "--- Configuring i3 ---"
I3_CONFIG_DIR="/home/saveli/.config/i3"
I3_CONFIG_FILE="$I3_CONFIG_DIR/config"
sudo -u saveli mkdir -p "$I3_CONFIG_DIR"
sudo -u saveli touch "$I3_CONFIG_FILE"

ALACRITTY_BINDING="bindsym \$mod+Return exec alacritty"
if ! grep -qF "$ALACRITTY_BINDING" "$I3_CONFIG_FILE"; then
    echo "Setting Alacritty as the default terminal in i3..."
    echo "$ALACRITTY_BINDING" | sudo -u saveli tee -a "$I3_CONFIG_FILE" > /dev/null
fi

I3_BELL_CONFIG="exec --no-startup-id xset -b"
if ! grep -qF "$I3_BELL_CONFIG" "$I3_CONFIG_FILE"; then
    echo "Disabling GUI bell in i3..."
    echo "$I3_BELL_CONFIG" | sudo -u saveli tee -a "$I3_CONFIG_FILE" > /dev/null
fi
echo "--- i3 configuration complete ---"
echo

# --- GITHUB CLI INSTALLATION & AUTHENTICATION ---
echo "--- GITHUB CLI INSTALLATION & AUTHENTICATION ---"
KEYRING_FILE="/usr/share/keyrings/githubcli-archive-keyring.gpg"
if [ ! -f "$KEYRING_FILE" ]; then
    echo "Adding GitHub CLI GPG key..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of="$KEYRING_FILE" \
    && chmod go+r "$KEYRING_FILE"
fi
SOURCES_FILE="/etc/apt/sources.list.d/github-cli.list"
if [ ! -f "$SOURCES_FILE" ]; then
    echo "Adding GitHub CLI repository to APT sources..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$KEYRING_FILE] https://cli.github.com/packages stable main" | tee "$SOURCES_FILE" > /dev/null
fi
if ! command -v gh &>/dev/null; then
    echo "GitHub CLI (gh) not found. Installing..."
    apt-get update
    apt-get install -y gh
else
    echo "GitHub CLI (gh) is already installed."
fi
if ! sudo -u saveli -i bash -c "gh auth status" &>/dev/null; then
    echo
    echo "#####################################################################"
    echo "#                                                                   #"
    echo "#  GitHub CLI is not authenticated. Please follow the prompts to    #"
    echo "#  log in. You will be asked to authenticate in your web browser.   #"
    echo "#                                                                   #"
    echo "#####################################################################"
    echo
    sudo -u saveli -i bash -c "gh auth login"
else
    echo "GitHub CLI is already authenticated for user 'saveli'."
fi
echo "--- GitHub CLI setup complete ---"
echo

# --- CLION INSTALLATION ---
echo "--- Installing JetBrains CLion ---"
if ! command -v clion &>/dev/null; then
    echo "CLion not found. Installing the latest version..."
    echo "Fetching the latest CLion download URL..."
    CLION_URL=$(curl -s 'https://data.services.jetbrains.com/products/releases?code=CL&latest=true&type=release' | jq -r '.CL[0].downloads.linux.link')
    if [[ -z "$CLION_URL" || "$CLION_URL" == "null" ]]; then
        echo "Error: Could not fetch the CLion download URL. Skipping installation."
    else
        echo "Downloading CLion from $CLION_URL"
        wget -q --show-progress -O /tmp/clion.tar.gz "$CLION_URL"
        echo "Extracting CLion to /opt..."
        CLION_DIR_NAME=$(tar -tf /tmp/clion.tar.gz | head -n 1 | cut -d'/' -f1)
        tar -xzf /tmp/clion.tar.gz -C /opt
        echo "Creating symbolic link..."
        ln -s "/opt/$CLION_DIR_NAME/bin/clion.sh" /usr/local/bin/clion
        rm /tmp/clion.tar.gz
        echo "CLion has been installed successfully. You can run it by typing 'clion'."
    fi
else
    echo "CLion is already installed."
fi
echo "--- CLion installation complete ---"
echo

echo "All setup tasks are complete."
echo "Script finished successfully."

# --- SCRIPT END ---
