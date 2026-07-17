import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  assetsInclude: ['**/*.glb'],
  build: {
    outDir: '../assets/lanyard',
    emptyOutDir: true,
    rollupOptions: {
      input: './src/main.jsx',
      output: {
        entryFileNames: 'lanyard-bundle.js',
        assetFileNames: 'lanyard-bundle.[ext]',
      }
    }
  }
})
