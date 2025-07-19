#!/bin/zsh

# Functions for each installation step
install_homebrew() {
  echo "🍺 Setting up Homebrew..."
  if test ! $(which brew); then
    echo "Installing Homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
  
  echo "Updating Homebrew recipes..."
  brew update
  
  echo "Installing Homebrew packages..."
  brew bundle --file=./Brewfile
}

apply_macos_preferences() {
  echo "🍎 Applying macOS preferences..."
  ./macos.sh
}

link_bin_scripts() {
  echo "🔗 Linking scripts from ./bin to ~/bin..."
  mkdir -p ~/bin
  
  # Make scripts executable first
  chmod +x ./bin/*
  
  for file in ./bin/*; do
    ln -sf "$PWD/$file" ~/bin/
  done
}

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  -b, --brew     Install Homebrew and packages only"
  echo "  -m, --macos    Apply macOS preferences only"
  echo "  -s, --scripts  Link bin scripts only"
  echo "  -a, --all      Run all steps (default)"
  echo ""
  echo "Examples:"
  echo "  $0              # Run all steps"
  echo "  $0 --scripts    # Only link bin scripts"
  echo "  $0 -b -s        # Install brew packages and link scripts"
}

# Parse command line arguments
RUN_BREW=false
RUN_MACOS=false
RUN_SCRIPTS=false
RUN_ALL=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -b|--brew)
      RUN_BREW=true
      RUN_ALL=false
      shift
      ;;
    -m|--macos)
      RUN_MACOS=true
      RUN_ALL=false
      shift
      ;;
    -s|--scripts)
      RUN_SCRIPTS=true
      RUN_ALL=false
      shift
      ;;
    -a|--all)
      RUN_ALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Run selected steps
if [[ "$RUN_ALL" == true ]]; then
  install_homebrew
  apply_macos_preferences
  link_bin_scripts
else
  if [[ "$RUN_BREW" == true ]]; then
    install_homebrew
  fi
  
  if [[ "$RUN_MACOS" == true ]]; then
    apply_macos_preferences
  fi
  
  if [[ "$RUN_SCRIPTS" == true ]]; then
    link_bin_scripts
  fi
fi

echo "✅ Setup complete!"
