import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@th7/enterprise-suite-ui"],
  poweredByHeader: false,
  reactStrictMode: true,
};

export default nextConfig;