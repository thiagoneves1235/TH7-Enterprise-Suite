import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@nexus/ui"],
  poweredByHeader: false,
  reactStrictMode: true,
};

export default nextConfig;