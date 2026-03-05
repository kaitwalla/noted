#!/bin/bash
# Sparkle Auto-Update Setup Script
# This script helps set up EdDSA keys for signing Sparkle updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$PROJECT_DIR/.sparkle-keys"

echo "=== Sparkle Auto-Update Setup ==="
echo ""

# Check if Sparkle is available via SPM
check_sparkle() {
    echo "Checking for Sparkle tools..."

    # Try to find the generate_keys tool from the Sparkle package
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
    SPARKLE_TOOLS=$(find "$DERIVED_DATA" -name "generate_keys" -path "*/Sparkle.framework/*" 2>/dev/null | head -1)

    if [ -z "$SPARKLE_TOOLS" ]; then
        echo "Sparkle tools not found in DerivedData."
        echo ""
        echo "To set up Sparkle signing:"
        echo "1. Build the project in Xcode first (this downloads Sparkle)"
        echo "2. Run this script again"
        echo ""
        echo "Alternatively, download Sparkle directly:"
        echo "  curl -L -o /tmp/Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-2.6.4.tar.xz"
        echo "  mkdir -p /tmp/Sparkle && tar -xf /tmp/Sparkle.tar.xz -C /tmp/Sparkle"
        echo "  /tmp/Sparkle/bin/generate_keys"
        exit 1
    fi

    SPARKLE_BIN_DIR=$(dirname "$SPARKLE_TOOLS")
    echo "Found Sparkle tools at: $SPARKLE_BIN_DIR"
    echo "$SPARKLE_BIN_DIR"
}

# Generate new keys
generate_keys() {
    echo ""
    echo "=== Generating EdDSA Keys ==="
    echo ""
    echo "This will generate a new EdDSA key pair for signing updates."
    echo "IMPORTANT: Keep the private key secure! Never commit it to git."
    echo ""

    mkdir -p "$KEYS_DIR"

    SPARKLE_BIN_DIR=$(check_sparkle)

    echo "Generating keys..."
    "$SPARKLE_BIN_DIR/generate_keys" -p "$KEYS_DIR/eddsa_private_key"

    echo ""
    echo "Keys generated successfully!"
    echo ""
    echo "Private key saved to: $KEYS_DIR/eddsa_private_key"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Add this public key to your Info.plist as SUPublicEDKey:"
    echo ""
    cat "$KEYS_DIR/eddsa_private_key.pub" 2>/dev/null || echo "   (Public key will be shown when you run generate_keys)"
    echo ""
    echo "2. Add $KEYS_DIR to .gitignore"
    echo "3. Back up your private key securely"
}

# Sign an update
sign_update() {
    local UPDATE_PATH="$1"

    if [ -z "$UPDATE_PATH" ]; then
        echo "Usage: $0 sign <path-to-update.zip>"
        exit 1
    fi

    if [ ! -f "$UPDATE_PATH" ]; then
        echo "Error: File not found: $UPDATE_PATH"
        exit 1
    fi

    SPARKLE_BIN_DIR=$(check_sparkle)

    if [ ! -f "$KEYS_DIR/eddsa_private_key" ]; then
        echo "Error: No private key found. Run '$0 generate' first."
        exit 1
    fi

    echo "Signing update: $UPDATE_PATH"
    SIGNATURE=$("$SPARKLE_BIN_DIR/sign_update" "$UPDATE_PATH" -s "$KEYS_DIR/eddsa_private_key")

    echo ""
    echo "=== Signature Generated ==="
    echo ""
    echo "EdDSA Signature:"
    echo "$SIGNATURE"
    echo ""
    echo "Set this as the APP_ED_SIGNATURE_MACOS environment variable on your server."
}

# Create an update package
create_update() {
    local APP_PATH="$1"
    local OUTPUT_PATH="$2"

    if [ -z "$APP_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
        echo "Usage: $0 package <path-to-App.app> <output.zip>"
        exit 1
    fi

    if [ ! -d "$APP_PATH" ]; then
        echo "Error: App not found: $APP_PATH"
        exit 1
    fi

    echo "Creating update package..."
    ditto -c -k --keepParent "$APP_PATH" "$OUTPUT_PATH"

    echo "Package created: $OUTPUT_PATH"
    echo ""
    echo "File size: $(stat -f%z "$OUTPUT_PATH") bytes"
    echo ""
    echo "Now sign the update with: $0 sign $OUTPUT_PATH"
}

# Show usage
usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  generate     Generate new EdDSA signing keys"
    echo "  sign <file>  Sign an update package (.zip)"
    echo "  package <app> <output.zip>  Create an update package from an app"
    echo ""
    echo "Example workflow:"
    echo "  1. $0 generate                           # One-time key generation"
    echo "  2. $0 package /path/to/NotedMenu.app update.zip"
    echo "  3. $0 sign update.zip"
    echo "  4. Upload update.zip and set APP_ED_SIGNATURE_MACOS on server"
}

# Main
case "${1:-}" in
    generate)
        generate_keys
        ;;
    sign)
        sign_update "$2"
        ;;
    package)
        create_update "$2" "$3"
        ;;
    *)
        usage
        ;;
esac
