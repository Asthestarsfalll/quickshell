import QtQuick 2.15
import QtTest 1.3
import "../../Common/functions/MetricsMath.js" as MetricsMath

TestCase {
    name: "Metrics"

    function test_logicalScaleTokens() {
        const cases = [0.75, 1.0, 1.25, 1.5]
        for (const factor of cases) {
            compare(MetricsMath.scaled(40, factor), 40 * factor)
            compare(MetricsMath.scaled(16, factor), 16 * factor)
            compare(MetricsMath.scaled(420, factor), 420 * factor)
        }
    }

    function test_halfLogicalPixelRounding() {
        compare(MetricsMath.scaled(17, 1.25), 21.5)
        compare(MetricsMath.scaled(1, 1.25), 1.5)
    }

    function test_outputScaleIsNotPartOfMetrics() {
        const valuesAtOutputScales = [1.0, 1.25, 1.5, 2.0]
            .map(_outputScale => MetricsMath.scaled(40, 1.0))
        compare(JSON.stringify(valuesAtOutputScales),
            JSON.stringify([40, 40, 40, 40]))
    }
}
