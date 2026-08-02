.pragma library

function scaled(value, uiScale) {
    return Math.round(Number(value) * Number(uiScale) * 2) / 2;
}
