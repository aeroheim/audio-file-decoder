import resolve from '@rollup/plugin-node-resolve';
import worker from 'rollup-plugin-web-worker-loader';
import babel from '@rollup/plugin-babel';
import filesize from 'rollup-plugin-filesize';
import copy from 'rollup-plugin-copy';
import { eslint } from 'rollup-plugin-eslint';
import { terser } from 'rollup-plugin-terser';

const extensions = ['.js', '.ts'];
export default {
  input: 'src/lib/audio-file-decoder.ts',
  output: {
    file: 'dist/audio-file-decoder.js',
    format: 'esm',
  },
  plugins: [
    resolve({ extensions }),
    eslint(),
    worker(),
    babel({
      presets: [
        '@babel/preset-env',
        '@babel/preset-typescript',
      ],
      plugins: [
        '@babel/plugin-proposal-class-properties',
      ],
      exclude: 'node_modules/**',
      extensions,
      babelHelpers: 'bundled',
    }),
    terser(),
    filesize(),
    copy({
      targets: [
        // the wasm is copied to the root directory instead of dist for more intuitive submodule access
        // clients will be able to import the wasm module with 'audio-file-decoder/decode-audio.wasm'
        { src: 'src/wasm/decode-audio.wasm', dest: '.' },
      ]
    }),
  ],
};