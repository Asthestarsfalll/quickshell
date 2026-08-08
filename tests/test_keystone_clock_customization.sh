#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

config=Services/PersonalizationConfig.qml
clock=Modules/Keystone/ClockContent/ClockContent.qml
page=Modules/ControlCenter/KeystonePage.qml
fonts=Common/Fonts.qml

for file in "$config" "$clock" "$page" "$fonts"; do
    test -f "$file" || fail "missing clock customization file: $file"
done

# The settings are structured below the keystone object and retain the
# existing visual defaults when an older config has no clock section.
require_text "$config" 'property bool keystoneHideDate: false'
require_text "$config" 'property int horizontalClockFontSize: 22'
require_text "$config" '"horizontalClock": {'
require_text "$config" '"fontSize": root.horizontalClockFontSize'
require_text "$config" '"axes": root.cloneMap(root.horizontalClockAxes)'
require_text "$config" '"digits": root.horizontalClockDigits'
require_text "$config" 'const horizontalClock = keystone.horizontalClock || {};'
require_text "$config" 'root.horizontalClockAxes = root.normalizedHorizontalClockAxes('
require_text "$config" 'root.horizontalClockDigits = root.normalizedHorizontalClockDigits('

# All persisted numeric inputs are finite and clamped to the real fvar or UI
# ranges; digit updates replace the object to preserve QML notifications.
require_text "$config" 'function normalizedHorizontalClockAxes(raw)'
require_text "$config" 'function normalizedHorizontalClockDigits(raw)'
require_text "$config" 'if (!isFinite(numberValue))'
require_text "$config" 'root.horizontalClockDigits = digits;'
require_text "$config" 'setHorizontalClockDigitValue(id, field, value, persist)'
require_text "$config" 'setHorizontalClockDigitColor(id, role, customColor, persist)'
for axis in wght wdth opsz GRAD ROND slnt; do
    require_text "$config" "\"$axis\":"
done
require_text "$config" '"wght": 1'
require_text "$config" '"wght": 1000'
require_text "$config" '"wdth": 25'
require_text "$config" '"wdth": 151'
require_text "$config" '"opsz": 6'
require_text "$config" '"opsz": 144'
require_text "$config" '"slnt": -10'
require_text "$config" '"slnt": 0'
for id in h0 h1 m0 m1; do
    require_text "$config" "\"$id\": ({"
done

# Horizontal style reads the configurable axes and transforms. Vertical style
# has its own fixed axes and fixed Font.Black typography.
require_text "$clock" 'readonly property var horizontalClockAxes:'
require_text "$clock" 'readonly property var verticalClockAxes:'
require_text "$clock" 'font.variableAxes: root.horizontalClockAxes'
require_text "$clock" 'font.variableAxes: root.verticalClockAxes'
require_text "$clock" 'readonly property real horizontalFontSize:'
require_text "$clock" 'property string digitId: "h0"'
require_text "$clock" 'Translate {'
require_text "$clock" 'Rotation {'
require_text "$clock" 'font.pixelSize: root.horizontalFontSize'
require_text "$clock" 'lineHeight: digitContainer.lineHeight'
require_text "$clock" 'y: -digitContainer.targetDigit * digitContainer.lineHeight'
require_text "$clock" 'readonly property bool hideDate:'
require_text "$clock" 'visible: !root.hideDate'
require_text "$clock" 'font.weight: Font.Black'

vertical_clock=$(sed -n '/id: verticalClockLayout/,$p' "$clock")
if printf '%s\n' "$vertical_clock" | grep -Fq 'root.horizontalClockAxes'; then
    fail "vertical Clock reads horizontal axes"
fi
rolling_digit=$(sed -n '/component RollingDigit/,/^    Row {/p' "$clock")
if printf '%s\n' "$rolling_digit" | grep -Fq 'font.weight: Font.Black'; then
    fail "horizontal RollingDigit still fixes Font.Black"
fi

# The preview is the real ClockContent component, and sliders distinguish live
# movement from persistence on release.
require_text "$page" 'import qs.Modules.Keystone.ClockContent'
require_text "$page" 'ClockContent {'
require_text "$page" 'edge: "top"'
require_text "$page" 'component ClockSliderSetting:'
require_text "$page" 'onMoved: clockSliderSetting.moved(value)'
require_text "$page" 'onCommitted: clockSliderSetting.committed(value)'
require_text "$page" 'setHorizontalClockFontSize(value, false)'
require_text "$page" 'setHorizontalClockFontSize(value, true)'
require_text "$page" 'setHorizontalClockDigitValue('
require_text "$page" 'setHorizontalClockDigitColor('
require_text "$page" 'property string selectedDigit: "h0"'
require_text "$page" '"value": "h0"'
require_text "$page" '"value": "m1"'

require_text "$fonts" 'readonly property string systemClock:'
if [ "$(rg -n 'FontLoader[[:space:]]*\{' "$clock" | wc -l)" -ne 0 ]; then
    fail "ClockContent introduced a second FontLoader"
fi

echo "keystone clock customization architecture audit passed"
