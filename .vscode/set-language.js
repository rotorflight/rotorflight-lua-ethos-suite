const fs = require("fs");
const path = require("path");

const lang = process.argv[2] || "en";
const settingsPath = path.join(process.cwd(), ".vscode", "settings.json");

let settings = {};
if (fs.existsSync(settingsPath)) {
  settings = JSON.parse(fs.readFileSync(settingsPath));
}

settings["rfsuite.deploy.language"] = lang;

fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));

console.log("Deployment language set to:", lang);
