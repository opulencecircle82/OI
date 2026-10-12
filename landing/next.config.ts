import type { NextConfig } from "next";

// Static export served by GitHub Pages at https://<user>.github.io/OI/
const nextConfig: NextConfig = {
  output: "export",
  basePath: "/OI",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
