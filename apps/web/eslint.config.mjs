import { defineConfig, globalIgnores } from 'eslint/config';
import nextCoreWebVitals from 'eslint-config-next/core-web-vitals';

const eslintConfig = defineConfig([
  ...nextCoreWebVitals,
  globalIgnores(['.next/**', 'out/**', 'next-env.d.ts']),
  {
    rules: {
      // Allow unused vars with _ prefix
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    },
  },
]);

export default eslintConfig;
