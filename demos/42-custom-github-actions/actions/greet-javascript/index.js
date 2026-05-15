// Minimal JavaScript action — no npm dependencies so we don't need to commit
// node_modules/ for the demo. In real projects, prefer `@actions/core` and
// bundle with `@vercel/ncc`.
//
// GitHub passes action inputs as env vars named INPUT_<NAME> (uppercased,
// spaces become underscores). Outputs are written to the file named by
// $GITHUB_OUTPUT as `name=value` lines.

const fs = require("fs");

const who = process.env.INPUT_WHO || "world";
const greeting = `Hello, ${who}! (from javascript)`;

console.log(greeting);

const outFile = process.env.GITHUB_OUTPUT;
if (outFile) {
  fs.appendFileSync(outFile, `greeting=${greeting}\n`);
} else {
  console.error("GITHUB_OUTPUT is not set; cannot emit outputs.");
  process.exit(1);
}
