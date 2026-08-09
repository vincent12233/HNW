const bcrypt = require("bcrypt");

async function main() {
  const hash = await bcrypt.hash("Admin@123456", 12);
  console.log(hash);
}

main();