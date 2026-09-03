import js from "@eslint/js";
import globals from "globals";
import { defineConfig } from "eslint/config";

export default defineConfig([
  // 1. Core recommended JavaScript rules (enforces 'no-undef')
  js.configs.recommended,

  // 2. Project-specific file overrides & environment globals
  {
    files: ["**/*.{js,mjs,cjs}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node, // Ensures 'process', 'console', 'Buffer', etc. are recognized
      },
    },
    rules: {
      "no-undef": "error", // Force explicit error highlighting for undefined variables
      "no-unused-vars": "warn",
    },
  },
]);