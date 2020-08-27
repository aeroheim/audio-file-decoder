import babel from '@rollup/plugin-babel';
import copy from 'rollup-plugin-copy';
import filesize from 'rollup-plugin-filesize';
import { eslint } from 'rollup-plugin-eslint';
import { terser } from 'rollup-plugin-terser';

export default {
  input: 'src/lib/audio-file-decoder.ts',
  output: {
    file: 'dist/audio-file-decoder.js',
    format: 'esm',
  },
  plugins: [
    eslint(),
    babel({
      presets: [
        '@babel/preset-env',
        '@babel/preset-typescript',
      ],
      plugins: [
        '@babel/plugin-proposal-class-properties',
      ],
      exclude: 'node_modules/**',
      extensions: ['.js', '.ts'],
      babelHelpers: 'bundled',
    }),
    terser(),
    filesize(),
    copy({
      targets: [
        { src: 'src/wasm/decode-audio.wasm', dest: 'dist' },
      ],
    }),
  ]
};
