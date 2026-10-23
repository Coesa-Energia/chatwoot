import fs from 'node:fs';
import path from 'node:path';
import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { aliases, vueOptions } from './vite.shared';
import yaml from '@rollup/plugin-yaml';

// Dev only. dashboard/i18n/index.js imports all 57 locales and each locale has
// ~48 JSON files (~2.5MB), which the unbundled dev server turns into 2000+ HTTP
// requests and ~140MB of JS on every cold page load. Two mitigations:
//  1. Only load the locales listed in DEV_LOCALES (default "en,pt_BR"; set
//     DEV_LOCALES=all to load every locale). Others become empty objects.
//  2. Inline each loaded locale's JSON files into its index.js, so a locale is
//     one request instead of ~48.
const DEV_LOCALES = (process.env.DEV_LOCALES || 'en,pt_BR').split(',');

const inlineLocaleJson = () => ({
  name: 'inline-locale-json',
  apply: 'serve' as const,
  enforce: 'pre' as const,
  transform(this: any, code: string, id: string) {
    const file = id.split('?')[0].replace(/\\/g, '/');
    if (/\/dashboard\/i18n\/index\.js$/.test(file)) {
      if (DEV_LOCALES.includes('all')) return null;
      return code.replace(
        /^import (\w+) from '\.\/locale\/(\w+)';?$/gm,
        (match, name, locale) =>
          DEV_LOCALES.includes(locale) ? match : `const ${name} = {};`
      );
    }
    if (!/\/i18n\/locale\/[^/]+\/index\.js$/.test(file)) return null;
    const dir = path.dirname(file);
    return code.replace(
      /^import (\w+) from '\.\/([\w-]+)\.json';?$/gm,
      (_match, name, jsonFile) => {
        const jsonPath = path.join(dir, `${jsonFile}.json`);
        this.addWatchFile(jsonPath);
        return `const ${name} = ${fs.readFileSync(jsonPath, 'utf8')};`;
      }
    );
  },
});

export default defineConfig({
  plugins: [ruby(), vue(vueOptions), yaml(), inlineLocaleJson()],
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
  resolve: { alias: aliases },
  server: {
    // Rails proxies /vite-dev through the Docker hostname "vite"; Vite 6 blocks
    // unknown Host headers and the browser gets 403 → blank dashboard.
    allowedHosts: ['vite', 'localhost'],
    // Browser is on the Windows host; the container hostname "vite" does not resolve there.
    hmr: {
      host: 'localhost',
      clientPort: 3036,
    },
    // The project lives on the WSL2 ext4 disk, so native inotify events work.
    // Only set VITE_USE_POLLING=1 if you run it from a Windows bind mount
    // (there polling saturates the I/O threadpool; also use a 3000ms interval).
    // VITE_DISABLE_WATCH=1 turns the watcher off (no HMR; reload manually).
    watch: process.env.VITE_DISABLE_WATCH ? null : {
      usePolling: process.env.VITE_USE_POLLING === '1',
      interval: 3000,
      binaryInterval: 3000,
      // Only app/javascript and config matter to the frontend, so skip the rest.
      ignored: [
        '**/node_modules/**',
        '**/.git/**',
        '**/.pnpm-store/**',
        ...[
          'log',
          'tmp',
          'public',
          'storage',
          'spec',
          'db',
          'docs',
          'swagger',
          'coverage',
          'vendor',
          '.bundle',
          'deployment',
          'clevercloud',
          '.circleci',
          '.github',
        ].map(dir => `${process.cwd()}/${dir}/**`),
      ],
    },
  },
});
