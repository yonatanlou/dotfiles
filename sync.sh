#!/bin/zsh

echo "🔄 Syncing dotfiles with current system configuration..."

# Function to sync Brewfile
sync_brewfile() {
  echo "🍺 Updating Brewfile..."
  if [[ -f "./generate_brewfile.sh" ]]; then
    chmod +x generate_brewfile.sh
    ./generate_brewfile.sh
    echo "✓ Brewfile updated"
  else
    echo "⚠️  generate_brewfile.sh not found"
  fi
}

# Function to sync VS Code settings
sync_vscode_config() {
  echo "💻 Syncing VS Code configuration..."
  
  # Create vscode directory if it doesn't exist
  mkdir -p ./vscode
  
  # Sync settings.json
  if [[ -f "$HOME/Library/Application Support/Code/User/settings.json" ]]; then
    cp "$HOME/Library/Application Support/Code/User/settings.json" "./vscode/settings.json"
    echo "✓ Synced VS Code settings"
  else
    echo "⚠️  VS Code settings.json not found"
  fi
  
  # Sync keybindings.json
  if [[ -f "$HOME/Library/Application Support/Code/User/keybindings.json" ]]; then
    cp "$HOME/Library/Application Support/Code/User/keybindings.json" "./vscode/keybindings.json"
    echo "✓ Synced VS Code keybindings"
  else
    echo "⚠️  VS Code keybindings.json not found"
  fi
  

}

# Main execution
sync_brewfile
sync_vscode_config

echo "✅ Sync complete!"
echo ""
echo "📝 Don't forget to commit your changes:"
echo "   git add ."
echo "   git commit -m 'sync: update system configuration'"