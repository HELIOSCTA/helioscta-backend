import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // `pg` is a CommonJS module with a native binary fallback. Mark it as
  // server-external so Next does not try to bundle it into the client or
  // edge runtime.
  serverExternalPackages: ["pg"],
};

export default nextConfig;
