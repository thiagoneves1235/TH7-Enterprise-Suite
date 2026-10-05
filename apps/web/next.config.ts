import type { NextConfig } from "next";

const isGitHubPages = process.env.NEXT_PUBLIC_GITHUB_PAGES === "true";

const nextConfig: NextConfig = {
  transpilePackages: ["@th7/enterprise-suite-ui"],
  poweredByHeader: false,
  reactStrictMode: true,
  output: "export",
  trailingSlash: true,
  basePath: isGitHubPages ? "/TH7-Enterprise-Suite" : undefined,
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
