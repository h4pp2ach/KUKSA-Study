import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: gauge

    property real value: 0
    property real minimumValue: 0
    property real maximumValue: 250

    property string speedColor: speedColorProvider(value)

    property real minimumValueAngle: -144
    property real maximumValueAngle: 144

    property real labelStepSize: 10
    property real tickmarkStepSize: 10
    property int minorTickmarkCount: 4

    property real outerRadius: Math.min(width, height) / 2
    property real labelInset: outerRadius / 2.2
    property real tickmarkInset: outerRadius / 4.2
    property real minorTickmarkInset: outerRadius / 4.2

    implicitWidth: 400
    implicitHeight: 400

    function speedColorProvider(v) {
        if (v < 60) {
            return "#32D74B"
        } else if (v > 60 && v < 150) {
            return "yellow"
        } else {
            return "red"
        }
    }

    function clampedValue(v) {
        return Math.max(minimumValue, Math.min(maximumValue, v))
    }

    function valueToAngle(v) {
        var clamped = clampedValue(v)
        var ratio = (clamped - minimumValue) / (maximumValue - minimumValue)
        return minimumValueAngle + ratio * (maximumValueAngle - minimumValueAngle)
    }

    function degreesToRadians(degrees) {
        return degrees * Math.PI / 180
    }

    function isMajorTick(v) {
        var ratio = (v - minimumValue) / tickmarkStepSize
        return Math.abs(ratio - Math.round(ratio)) < 0.001
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: "#1E1E1E"
        radius: 360
        opacity: 0.5
    }

    Canvas {
        id: arcCanvas

        anchors.fill: parent

        property real paintedValue: gauge.value
        property real paintedMinimumValue: gauge.minimumValue
        property real paintedMaximumValue: gauge.maximumValue
        property string paintedSpeedColor: gauge.speedColor
        property real paintedOuterRadius: gauge.outerRadius

        onPaintedValueChanged: requestPaint()
        onPaintedMinimumValueChanged: requestPaint()
        onPaintedMaximumValueChanged: requestPaint()
        onPaintedSpeedColorChanged: requestPaint()
        onPaintedOuterRadiusChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var r = gauge.outerRadius

            var startAngle = gauge.valueToAngle(gauge.minimumValue) - 90
            var endAngle = gauge.valueToAngle(gauge.value) - 90

            ctx.beginPath()
            ctx.lineWidth = r * 0.225
            ctx.strokeStyle = gauge.speedColor
            ctx.arc(
                cx,
                cy,
                r - ctx.lineWidth / 2,
                gauge.degreesToRadians(startAngle),
                gauge.degreesToRadians(endAngle)
            )
            ctx.stroke()
        }
    }

    Item {
        id: faceLayer

        anchors.fill: parent

        property real cx: width / 2
        property real cy: height / 2

        Repeater {
            id: majorTickRepeater

            model: Math.floor((gauge.maximumValue - gauge.minimumValue) / gauge.tickmarkStepSize) + 1

            delegate: Image {
                id: majorTick

                property real tickValue: gauge.minimumValue + index * gauge.tickmarkStepSize

                visible: tickValue <= gauge.maximumValue + 0.001

                source: "qrc:/assets/tickmark.svg"
                width: gauge.outerRadius * 0.018
                height: gauge.outerRadius * 0.15

                x: faceLayer.cx - width / 2
                y: faceLayer.cy - gauge.outerRadius + gauge.tickmarkInset

                antialiasing: true
                asynchronous: true
                smooth: true

                transform: Rotation {
                    origin.x: majorTick.width / 2
                    origin.y: faceLayer.cy - majorTick.y
                    angle: gauge.valueToAngle(majorTick.tickValue)
                }
            }
        }

        Repeater {
            id: minorTickRepeater

            property real minorStep: gauge.tickmarkStepSize / (gauge.minorTickmarkCount + 1)

            model: Math.floor((gauge.maximumValue - gauge.minimumValue) / minorStep) + 1

            delegate: Rectangle {
                id: minorTick

                property real tickValue: gauge.minimumValue + index * minorTickRepeater.minorStep

                visible: tickValue <= gauge.maximumValue + 0.001
                         && !gauge.isMajorTick(tickValue)

                implicitWidth: gauge.outerRadius * 0.01
                implicitHeight: gauge.outerRadius * 0.03

                width: implicitWidth
                height: implicitHeight

                x: faceLayer.cx - width / 2
                y: faceLayer.cy - gauge.outerRadius + gauge.minorTickmarkInset

                antialiasing: true
                smooth: true

                color: tickValue <= gauge.value ? "white" : "darkGray"

                transform: Rotation {
                    origin.x: minorTick.width / 2
                    origin.y: faceLayer.cy - minorTick.y
                    angle: gauge.valueToAngle(minorTick.tickValue)
                }
            }
        }

        Repeater {
            id: labelRepeater

            model: Math.floor((gauge.maximumValue - gauge.minimumValue) / gauge.labelStepSize) + 1

            delegate: Text {
                id: tickLabel

                property real labelValue: gauge.minimumValue + index * gauge.labelStepSize
                property real labelAngle: gauge.degreesToRadians(gauge.valueToAngle(labelValue) - 90)
                property real labelRadius: gauge.outerRadius - gauge.labelInset

                visible: labelValue <= gauge.maximumValue + 0.001

                text: labelValue.toFixed(0)

                font.pixelSize: Math.max(6, gauge.outerRadius * 0.05)
                color: labelValue <= gauge.value ? "white" : "#777776"
                antialiasing: true

                x: faceLayer.cx + Math.cos(labelAngle) * labelRadius - width / 2
                y: faceLayer.cy + Math.sin(labelAngle) * labelRadius - height / 2
            }
        }
    }

    Item {
        id: needleLayer

        anchors.centerIn: parent
        width: 0
        height: 0

        visible: gauge.value.toFixed(0) > 0
        rotation: gauge.valueToAngle(gauge.value)

        Item {
            id: needleItem

            x: -needle.width / 2
            y: -gauge.outerRadius * 0.78

            width: needle.width
            height: gauge.outerRadius * 0.27

            Image {
                id: needle

                source: "qrc:/assets/needle.svg"

                height: parent.height
                width: height * 0.1

                asynchronous: true
                antialiasing: true
                smooth: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "white"
                    shadowOpacity: 1.0
                    shadowBlur: 0.6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 12
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        Label {
            text: gauge.value.toFixed(0)

            font.pixelSize: 85
            font.family: "Inter"
            font.weight: Font.DemiBold

            color: "#01E6DE"

            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "MPH"

            font.pixelSize: 46
            font.family: "Inter"
            font.weight: Font.Normal

            color: "#01E6DE"

            Layout.alignment: Qt.AlignHCenter
        }
    }
}