import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";
import reactPlugin from "eslint-plugin-react";

// eslint-plugin-react 7.37.x still calls removed ESLint 10 RuleContext APIs
// (context.getFilename). Upstream fix: jsx-eslint/eslint-plugin-react#4022.
// Until a compatible release ships, keep the plugin installed via
// eslint-config-next but turn every react/* rule off so ESLint 10 can run.
const reactRulesOff = Object.fromEntries(
  Object.keys(reactPlugin.rules ?? {}).map((name) => [`react/${name}`, "off"]),
);

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
  {
    rules: {
      ...reactRulesOff,
      // Existing admin UI uses `any` at API boundaries; keep visible as warnings.
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
        },
      ],
      // Admin pages intentionally load list data on mount via useEffect → setState.
      // The React Compiler rule rejects that pattern; keep CI green and revisit
      // page-by-page with query libraries when we standardize data fetching.
      "react-hooks/set-state-in-effect": "off",
      // Many mount-once loaders omit unstable function identities on purpose.
      "react-hooks/exhaustive-deps": "warn",
    },
  },
]);

export default eslintConfig;
