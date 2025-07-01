#!/usr/bin/env bash
# scaffold-vrtw.sh  —  Vite + React TS + Tailwind 4 + ESLint 9 (flat) + Prettier
# Keeps both tsconfig.app.json and tsconfig.node.json and customizes them.
set -euo pipefail

###############################################################################
# 0   Require pnpm
###############################################################################
command -v pnpm >/dev/null 2>&1 || {
  echo "✖  pnpm isn’t installed.  Install it with:  npm i -g pnpm"; exit 1; }

###############################################################################
# 1   Project name
###############################################################################
if [[ $# -ge 1 ]]; then
  APP_NAME="$1"
else
  read -rp "Project name: " APP_NAME
  [[ -z "$APP_NAME" ]] && { echo "✖  Name required"; exit 1; }
fi

###############################################################################
# 2   Scaffold Vite React-TS template
###############################################################################
pnpm create vite@latest "$APP_NAME" --template react-ts --no-git
cd "$APP_NAME"

###############################################################################
# 3   Dev dependencies
###############################################################################
pnpm add -D \
  tailwindcss @tailwindcss/vite \
  eslint@^9 @eslint/js eslint-config-prettier \
  eslint-plugin-react eslint-plugin-react-hooks \
  eslint-plugin-react-refresh eslint-plugin-jsx-a11y \
  @typescript-eslint/parser @typescript-eslint/eslint-plugin \
  typescript-eslint \
  prettier

###############################################################################
# 4   vite.config.ts (unchanged)
###############################################################################
cat > vite.config.ts <<'VITE'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
});
VITE

###############################################################################
# 5   TypeScript configs (root + app + node)
###############################################################################

# Root just references
cat > tsconfig.json <<'TSCONFIG'
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
TSCONFIG

# App: browser build (DOM libs, JSX)
cat > tsconfig.app.json <<'APP'
{
  "compilerOptions": {
    "target": "ESNext",
    "useDefineForClassFields": true,
    "lib": ["DOM", "DOM.Iterable", "ESNext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": [
    "./src",
    "./@types",
    "./mocks",
    "scripts",
    "./**.js",
    "./**.ts",
    "eslint.config.js"
  ],
  "exclude": ["dist"]
}
APP

# Node: config/scripts (Node libs, no JSX, includes config/scripts)
cat > tsconfig.node.json <<'NODE'
{
  "compilerOptions": {
    "target": "ESNext",
    "useDefineForClassFields": true,
    "lib": ["ESNext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": [
    "./vite.config.ts",
    "./@types",
    "scripts",
    "./**.js",
    "./**.ts"
  ],
  "exclude": ["dist"]
}
NODE

###############################################################################
# 6   ESLint flat-config (overwrite eslint.config.js)
###############################################################################
cat > eslint.config.js <<'ESLINT'
import eslintConfigPrettier from "eslint-config-prettier";
import jsxA11y from "eslint-plugin-jsx-a11y";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig([
  {
    ignores: [
      "**/.vscode",
      "**/node_modules",
      "**/build",
      "**/dist",
      "**/.github",
      "**/.idea"
    ]
  },
  ...tseslint.configs.recommended,
  {
    files: ["**/*.{js,jsx,ts,tsx}"],
    plugins: {
      react,
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
      "jsx-a11y": jsxA11y
    },
    settings: { react: { version: "detect" } },
    rules: {
      /* React Hooks */
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",

      /* React */
      "react/react-in-jsx-scope": "off",
      "react/prop-types": "off",
      "react/jsx-uses-react": "off",
      "react/jsx-uses-vars": "error",
      "react/jsx-key": "error",
      "react/no-unescaped-entities": "warn",

      /* React Refresh */
      "react-refresh/only-export-components": [
        "warn",
        { "allowConstantExport": true }
      ],

      /* Accessibility (subset) */
      "jsx-a11y/alt-text": "warn",
      "jsx-a11y/anchor-has-content": "warn",
      "jsx-a11y/anchor-is-valid": "warn",
      "jsx-a11y/aria-props": "warn",
      "jsx-a11y/aria-proptypes": "warn",
      "jsx-a11y/aria-unsupported-elements": "warn",
      "jsx-a11y/role-has-required-aria-props": "warn",
      "jsx-a11y/role-supports-aria-props": "warn",

      /* TypeScript */
      "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
      "@typescript-eslint/no-explicit-any": "warn",

      /* General */
      "indent": "off",
      "no-console": "warn",
      "prefer-const": "error",
      "no-var": "error"
    }
  },
  eslintConfigPrettier
]);
ESLINT

###############################################################################
# 7   Tailwind import
###############################################################################
mkdir -p src
cat > src/index.css <<'CSS'
@import "tailwindcss";
CSS

###############################################################################
# 8   Prettier config & lint script
###############################################################################
echo '{}' > .prettierrc
pnpm pkg set scripts.lint="eslint --max-warnings 0 ."

###############################################################################
# 9   Done
###############################################################################
cat <<EOF

✅  $APP_NAME scaffolded:

   • Root tsconfig.json with references
   • tsconfig.app.json (browser) and tsconfig.node.json (Node/config)
   • ESLint flat-config (eslint.config.js) overriding Vite default
   • Vite + React TS + Tailwind 4 + Prettier

Next steps:

   cd $APP_NAME
   pnpm dev      # start Vite dev server
   pnpm lint     # run ESLint

If pnpm 10 warns "Ignored build scripts: esbuild", approve once with:
   pnpm approve-builds

Happy hacking! 🚀
EOF