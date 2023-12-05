/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    isrMemoryCacheSize: 0,
  },
};

module.exports = nextConfig;
