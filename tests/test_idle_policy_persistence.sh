#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
idle="$repo_dir/Services/IdleService.qml"
quick_settings="$repo_dir/Modules/QuickSettings/QuickSettingsSurface.qml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

require_text "$idle" 'property bool inhibited: false'
require_text "$idle" '"inhibited": false'
require_text "$idle" 'values, "inhibited", defaults.inhibited'
require_text "$idle" '"inhibited": root.inhibited'
require_text "$idle" 'root.savePolicy();'
require_text "$idle" 'typeof data[key] === "boolean"'
require_text "$idle" 'function needsPolicyMigration(data)'
require_text "$idle" 'typeof data.inhibited !== "boolean"'
reject_text "$idle" 'property alias inhibited: persistentState.inhibited'
reject_text "$idle" 'reloadableId: "clavis-idle-state"'
require_text "$quick_settings" 'case "caffeine": return IdleService.inhibited;'
require_text "$quick_settings" 'IdleService.toggleInhibited();'
reject_text "$quick_settings" 'property bool caffeine'

echo "idle policy persistence architecture audit passed"
