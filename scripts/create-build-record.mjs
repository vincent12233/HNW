import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { validateBuild } from "./release-verification.mjs";
const image = "ghcr.io/vincent12233/hnw-api";
const digest = process.env.IMAGE_DIGEST;
if (!/^sha256:[a-f0-9]{64}$/.test(digest ?? ""))
  throw new Error("Invalid build digest");
const inspect = (ref) =>
  JSON.parse(
    execFileSync("docker", ["buildx", "imagetools", "inspect", "--raw", ref], {
      encoding: "utf8",
    }),
  );
const index = inspect(`${image}@${digest}`);
const platforms = [];
for (const manifest of index.manifests ?? []) {
  if (manifest.platform?.os !== "linux") continue; // OCI provenance attestations are not runtime images.
  const child = inspect(`${image}@${manifest.digest}`);
  platforms.push({
    platform: `${manifest.platform.os}/${manifest.platform.architecture}${manifest.platform.variant ? `/${manifest.platform.variant}` : ""}`,
    digest: manifest.digest,
    configDigest: child.config.digest,
  });
}
const build = validateBuild({
  schema: 1,
  commit: process.env.GITHUB_SHA,
  image,
  digest,
  platforms,
  buildRunId: process.env.GITHUB_RUN_ID,
});
mkdirSync("build-record", { recursive: true });
writeFileSync("build-record/build.json", JSON.stringify(build, null, 2));
