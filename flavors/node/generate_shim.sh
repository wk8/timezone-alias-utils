# usage: ./generate_tz_shim.sh <override1> <override2> ...
# where each (optional) override file contains a JSON file with extra aliases, e.g.:
# {
#   "my_custom_tz": "America/Los_Angeles"
# }

# both the shebang and
# export TZ_GROUPS=[...]
# are prepended by the Dockerfile

# whole idea of this script is to:
# 1. render a node script that compares the TZs available in the version of node, and renders the shim script
# 2. run that script
# 3. replace the node binary by a wrapper script that adds the right flag to always require that sh

(set -u) >/dev/null 2>&1 && set -u
set -e

SHIM_DIR=/usr/local/lib/node-preload
TZ_SHIM_PATH="$SHIM_DIR/tz-alias-shim.cjs"

mkdir -p "$SHIM_DIR"

# render the node script
NODE_SCRIPT=/tmp/generate_tz_shim.js
printf "const TZ_GROUPS = $TZ_GROUPS;\n\n" > "$NODE_SCRIPT"
printf "const TZ_SHIM_PATH = '$TZ_SHIM_PATH';\n\n" >> "$NODE_SCRIPT"
cat <<'EOF' >> "$NODE_SCRIPT"

const fs = require('fs');
const path = require('path');

// can't use Intl.supportedValuesOf(tz) - doesn't exist in node < 18
function isSupportedTimeZone(tz) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    new Date().toLocaleString('en-US', { timeZone: tz });
    return true;
  } catch (e) {
    return false;
  }
}

function buildTzAliases(groups, overrides) {
  const aliases = {};

  for (const group of groups) {
    const canonical = group.find(isSupportedTimeZone);

    if (!canonical) {
      console.warn("No supported time zone found in group:", group);
      continue;
    }

    for (const tz of group) {
      if (tz === canonical) continue;

      if (!isSupportedTimeZone(tz)) {
        if (aliases[tz] && aliases[tz] !== canonical) {
          console.warn(`Conflict for alias ${tz}: ${aliases[tz]} vs ${canonical}`);
        }
        aliases[tz] = canonical;
      }
    }
  }
  
  for (const overrideFilePath of overrides) {
    const parsed = parseOverrideFile(overrideFilePath);
    
    for (const [alias, canonical] of Object.entries(parsed)) {
      if (!isSupportedTimeZone(canonical)) {
        console.warn(`Ignoring alias ${alias} pointing to non-supported TZ ${canonical}`);
        continue;
      }
      
      if (aliases[alias] && aliases[alias] !== canonical) {
        console.warn(`Conflict for alias ${alias}: ${aliases[alias]} vs ${canonical}`);
      }

      aliases[alias] = canonical;
    }
  }

  return aliases;
}

function parseOverrideFile(overrideFilePath) {
  const fullPath = path.resolve(overrideFilePath);
  
  const raw = fs.readFileSync(fullPath, 'utf8');
  const parsed = JSON.parse(raw);
  
  // must be a plain object
  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    Array.isArray(parsed)
  ) {
    console.error(`ERROR: Override file ${fullPath} must contain a JSON object.`);
    process.exit(1);
  }

  // validate every key/value is string => string
  for (const [k, v] of Object.entries(parsed)) {
    if (typeof k !== 'string') {
      console.error(`ERROR: Override file ${fullPath} contains a non-string key: ${k}`);
      process.exit(1);
    }

    if (typeof v !== 'string') {
      console.error(`ERROR: Override file ${fullPath} has key ${k} with non-string value: ${v}`);
      process.exit(1);
    }
  }
  
  return parsed;
}

function buildTzAliasesVarDeclaration(aliases) {
  let result = 'const TZ_ALIASES = {\n';
  
  for (const [alias, canonical] of Object.entries(aliases).sort()) {
    result += `  "${alias}": "${canonical}",\n`;
  }
  
  result += '};\n';
  
  return result;
}

function buildShimScript(aliases) {
  let result = buildTzAliasesVarDeclaration(aliases);

  result += `
function _tz_shim_normalizeTimeZone(tz) {
  return TZ_ALIASES[tz] || tz;
}

const _tz_shim_originalDateTimeFormat = Intl.DateTimeFormat;

function _tz_shim_DateTimeFormat(locale, options, ...rest) {
  if (options && typeof options.timeZone === 'string') {
    options = { ...options, timeZone: _tz_shim_normalizeTimeZone(options.timeZone) };
  }
  return Reflect.construct(_tz_shim_originalDateTimeFormat, [locale, options, ...rest]);
}

Object.setPrototypeOf(_tz_shim_DateTimeFormat, _tz_shim_originalDateTimeFormat);
_tz_shim_DateTimeFormat.prototype = _tz_shim_originalDateTimeFormat.prototype;
Intl.DateTimeFormat = _tz_shim_DateTimeFormat;

const _tz_shim_originalToLocaleString = Date.prototype.toLocaleString;

Date.prototype.toLocaleString = function (locale, options, ...rest) {
  if (options && typeof options.timeZone === 'string') {
    options = { ...options, timeZone: _tz_shim_normalizeTimeZone(options.timeZone) };
  }
  return _tz_shim_originalToLocaleString.call(this, locale, options, ...rest);
};
`;

  return result;
}

function main() {
  const aliases = buildTzAliases(TZ_GROUPS, process.argv.slice(2));

  if (Object.keys(aliases).length == 0) {
    // nothing to do!!
    console.log('No TZ to alias!');
    return;
  }

  fs.writeFileSync(TZ_SHIM_PATH, buildShimScript(aliases), 'utf8');
}

main();
EOF

# run it
node "$NODE_SCRIPT" "$@"

rm "$NODE_SCRIPT"

# then finally add the node wrapper
if [ -f "$TZ_SHIM_PATH" ]; then
  NODE_BIN_PATH=$(command -v node) || {
    printf '%s\n' "node not found in PATH" >&2
    exit 1
  }
  ORIGINAL_NODE_BIN_PATH="${NODE_BIN_PATH}-original"

  mv "$NODE_BIN_PATH" "$ORIGINAL_NODE_BIN_PATH"

  cat <<EOF > "$NODE_BIN_PATH"
#!/bin/sh

export TZ_SHIM_REQUIRE_FLAG="--require=$TZ_SHIM_PATH"
export ORIGINAL_NODE_BIN_PATH="$ORIGINAL_NODE_BIN_PATH"

EOF
  cat <<'EOF' >> "$NODE_BIN_PATH"
if [ -z "${NODE_OPTIONS+x}" ] || [ -z "$NODE_OPTIONS" ]; then
    NODE_OPTIONS="$TZ_SHIM_REQUIRE_FLAG"
else
    NODE_OPTIONS="$TZ_SHIM_REQUIRE_FLAG $NODE_OPTIONS"
fi

export NODE_OPTIONS

exec "$ORIGINAL_NODE_BIN_PATH" "$@"
EOF

  chmod +x "$NODE_BIN_PATH"
fi # end of node wrapper script

# cleanup
rm "$0"
