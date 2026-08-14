const bcrypt = require("bcrypt");

async function main() {
  const password = process.env.PASSWORD_TO_HASH;
  if (!password || password.length < 12) {
    throw new Error("PASSWORD_TO_HASH must contain at least 12 characters");
  }
  const hash = await bcrypt.hash(password, 12);
  console.log(hash);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
