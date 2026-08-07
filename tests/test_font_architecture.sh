#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    rg -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

assert_not_contains() {
    if rg -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

fonts=Common/Fonts.qml
typography=Common/Typography.qml
font_service=Services/FontService.qml
config=Services/PersonalizationConfig.qml
theme=Modules/ControlCenter/ThemePage.qml
clock=Modules/Sidebars/Left/system/SystemClockCard.qml
calendar=Modules/Sidebars/Left/system/SystemCalendarCard.qml
liquid=Modules/Sidebars/Left/system/SystemLiquidMetricCard.qml

for file in "$fonts" "$typography" "$font_service" "$config" "$theme" \
    "$clock" "$calendar" "$liquid"; do
    test -f "$file" || fail "missing font architecture file: $file"
done

assert_contains "$fonts" 'property string configuredUi'
assert_contains "$fonts" 'property string configuredMono'
assert_contains "$fonts" 'property string configuredNumeric'
assert_contains "$fonts" 'property string configuredExpressive'
assert_contains "$fonts" 'readonly property string defaultNumeric:'
assert_contains "$fonts" 'readonly property string ui:'
assert_contains "$fonts" 'readonly property string mono:'
assert_contains "$fonts" 'readonly property string numeric:'
assert_contains "$fonts" 'readonly property string expressive:'
assert_contains "$fonts" 'readonly property string systemClock:'
assert_contains "$fonts" 'readonly property string materialSymbolsRounded:'
assert_contains "$fonts" 'readonly property string materialSymbolsOutlined:'
assert_contains "$fonts" 'readonly property string nerdFont:'
assert_contains "$fonts" 'readonly property string nerdSymbols:'
assert_contains "$fonts" 'readonly property string fontAwesome:'
assert_contains "$fonts" 'FontLoader {'
assert_contains "$fonts" 'GRAD,ROND,opsz,slnt,wdth,wght.ttf'
assert_contains "$fonts" 'function setConfiguredFamily(role, family)'
assert_contains "$fonts" 'function cssFamily(family)'

for style in displaySmall headlineMedium headlineSmall titleLarge titleMedium \
    titleSmall bodyLarge bodyMedium bodySmall labelLarge labelMedium labelSmall; do
    assert_contains "$typography" "readonly property QtObject $style:"
    assert_contains "$typography" "readonly property int pixelSize:"
done
assert_contains Widgets/common/SettingsActionRow.qml \
    'font.family: Typography.bodyMedium.family'
assert_contains Widgets/common/MaterialCard.qml \
    'font.family: Typography.titleMedium.family'

assert_contains "$font_service" 'Qt.fontFamilies()'
assert_contains "$font_service" 'isTechnicalFamily(family)'
assert_contains "$font_service" 'property var availableFamilies'
assert_contains "$font_service" 'readonly property var fontOptions'

assert_contains "$config" 'function setFontFamily(role, family)'
assert_contains "$config" 'function resetFontFamilies()'
assert_contains "$config" '"fonts": {'
assert_contains "$config" 'Fonts.setConfiguredFamilies('

for role in ui mono numeric expressive; do
    assert_contains "$theme" "setFontFamily(\"$role\""
done
assert_contains "$theme" 'title: qsTr("字体")'
assert_contains "$theme" 'searchable: true'
assert_contains "$theme" '恢复默认字体'

assert_contains "$clock" 'Fonts.systemClock'
assert_contains "$clock" 'Fonts.familyAvailable(Fonts.systemClock)'
assert_not_contains "$clock" 'FontLoader {'
assert_contains "$calendar" 'Fonts.expressive'
assert_not_contains "$calendar" 'FontLoader {'
assert_contains "$liquid" 'Fonts.expressive'
assert_not_contains "$liquid" 'FontLoader {'

for file in Common/Sizes.qml; do
    for token in fontFamily fontFamilyMono fontIcon fontMaterialSymbols \
        typeDisplaySmall typeHeadlineMedium typeHeadlineSmall typeTitleLarge \
        typeTitleMedium typeTitleSmall typeBodyLarge typeBodyMedium \
        typeBodySmall typeLabelLarge typeLabelMedium typeLabelSmall; do
        assert_not_contains "$file" "$token"
    done
done

if rg -n 'Sizes\.(fontFamily|fontFamilyMono|fontIcon|fontMaterialSymbols|type(Display|Headline|Title|Body|Label))' \
        --glob '*.qml' . >/dev/null; then
    fail "legacy Sizes font or typography tokens remain in QML"
fi

if rg -n 'Metrics\.(uiScale|scaled)|MetricsMath|setUiScale|uiScale' \
        --glob '*.qml' Common Modules Services AppShell.qml >/dev/null; then
    fail "removed dynamic UI scale code remains in the font audit surface"
fi

for literal in \
    'LXGW WenKai GB Screen' \
    'JetBrainsMono Nerd Font' \
    'Material Symbols Rounded' \
    'Material Symbols Outlined' \
    'Font Awesome 6 Free Solid' \
    'Symbols Nerd Font Mono'; do
    matches=$(rg -l --fixed-strings --glob '*.qml' "$literal" . \
        | sed 's#^\./##' || true)
    if [ "$matches" != "Common/Fonts.qml" ]; then
        fail "font literal is not centralized: $literal ($matches)"
    fi
done

if rg -n 'Fonts\.(chinese|english|latin|serif|sansSerif)' \
        --glob '*.qml' . >/dev/null; then
    fail "language-specific font roles were introduced"
fi

for file in \
    Modules/Sidebars/Left/WeatherHumidityCard.qml \
    Modules/Sidebars/Left/WeatherVisibilityCard.qml \
    Modules/Sidebars/Left/WeatherPressureCard.qml \
    Modules/Sidebars/Left/WeatherAstroCard.qml \
    Modules/Sidebars/Left/WeatherMetricCard.qml \
    Modules/Sidebars/Left/WeatherBlob.qml \
    Modules/Sidebars/Left/WeatherInsightCard.qml; do
    assert_contains "$file" 'Fonts.expressive'
done

for file in \
    Modules/Sidebars/Left/WeatherTrendChart.qml \
    Modules/Sidebars/Left/HourlyForecastTrendCard.qml \
    Modules/Sidebars/Left/DailyForecastTrendCard.qml; do
    assert_contains "$file" 'Fonts.numeric'
    assert_contains "$file" 'onNumericChanged()'
    assert_contains "$file" 'requestPaint()'
done

test -f assets/fonts/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf \
    || fail "bundled Google Sans Flex variable font is missing"

echo "font architecture audit passed"
