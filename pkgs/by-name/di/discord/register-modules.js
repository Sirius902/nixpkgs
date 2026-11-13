// Registers the modules this package bundles, then hands over to Discord's
// own entry point (@main@). See linux.nix.
const path = require("path");
require("module").globalPaths.push(path.join(process.resourcesPath, "..", "modules"));
const main = path.join(__dirname, "@main@");
// Discord derives its resources path from require.main.filename
require.main.filename = main;
require(main);
