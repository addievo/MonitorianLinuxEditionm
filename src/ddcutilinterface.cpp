#include "ddcutilinterface.h"
#include <QDebug>
#include <QRegularExpression>

DDCUtilInterface::DDCUtilInterface(QObject *parent)
    : QObject(parent)
    , m_isAvailable(false)
{
    m_isAvailable = checkDDCUtilInstalled();
    if (m_isAvailable) {
        qDebug() << "ddcutil is available on this system";
    }
}

DDCUtilInterface::~DDCUtilInterface()
{
}

bool DDCUtilInterface::isAvailable() const
{
    return m_isAvailable;
}

bool DDCUtilInterface::checkDDCUtilInstalled()
{
    QProcess process;
    process.start("which", QStringList() << "ddcutil");
    process.waitForFinished();

    if (process.exitCode() != 0) {
        qWarning() << "ddcutil is not installed on this system";
        return false;
    }

    return true;
}

QString DDCUtilInterface::executeCommand(const QString& command, const QStringList& arguments)
{
    QProcess process;
    process.start(command, arguments);
    process.waitForFinished(5000); // 5 second timeout

    if (process.exitCode() != 0) {
        qWarning() << "Command execution failed:" << command << arguments;
        qWarning() << "Error:" << process.readAllStandardError();
        return QString();
    }

    return process.readAllStandardOutput();
}
QList<DDCUtilInterface::MonitorInfo> DDCUtilInterface::detectMonitors()
{
    if (!m_isAvailable) {
        qWarning() << "Cannot detect monitors: ddcutil is not available";
        return QList<MonitorInfo>();
    }

    qDebug() << "Detecting monitors using ddcutil...";
    QString output = executeCommand("ddcutil", QStringList() << "detect");
    if (output.isEmpty()) {
        qWarning() << "ddcutil detect command returned no output";
        return QList<MonitorInfo>();
    }

    // Debug the output
    qDebug() << "Raw output from ddcutil detect:";
    qDebug() << output.left(500) + "..."; // First 500 chars to avoid log spam

    QMap<QString, MonitorInfo> monitors = parseDetectOutput(output);
    qDebug() << "Detected" << monitors.size() << "monitors";

    // Get current brightness values for each monitor
    for (auto it = monitors.begin(); it != monitors.end(); ++it) {
        it.value().currentBrightness = getBrightness(it.key());
        qDebug() << "Monitor" << it.key() << "brightness:" << it.value().currentBrightness;
    }

    return monitors.values();
}

QMap<QString, DDCUtilInterface::MonitorInfo> DDCUtilInterface::parseDetectOutput(const QString& output)
{
    QMap<QString, MonitorInfo> monitors;
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);

    MonitorInfo currentMonitor;
    bool parsingDisplay = false;

    qDebug() << "Parsing" << lines.size() << "lines of ddcutil output";

    for (const QString& line : lines) {
        // New display found
        if (line.startsWith("Display")) {
            // Save previous monitor if we have one
            if (!currentMonitor.id.isEmpty()) {
                monitors[currentMonitor.id] = currentMonitor;
            }

            // Start new monitor
            currentMonitor = MonitorInfo();
            parsingDisplay = true;
        }
        // I2C bus line contains the monitor ID
        else if (parsingDisplay && line.contains("I2C bus:")) {
            QRegularExpression reDisplay("/dev/i2c-(\\d+)");
            QRegularExpressionMatch match = reDisplay.match(line);
            if (match.hasMatch()) {
                currentMonitor.id = match.captured(1);
                qDebug() << "Found monitor with ID:" << currentMonitor.id;
                currentMonitor.maxBrightness = 100;
            }
        }
        // Get manufacturer
        else if (line.contains("Mfg id:")) {
            QRegularExpression reManufacturer("Mfg id:\\s+(.+)");
            QRegularExpressionMatch match = reManufacturer.match(line);
            if (match.hasMatch()) {
                currentMonitor.manufacturer = match.captured(1).trimmed();
                qDebug() << "Manufacturer:" << currentMonitor.manufacturer;
            }
        }
        // Get model name
        else if (line.contains("Model:")) {
            QRegularExpression reName("Model:\\s+(.+)");
            QRegularExpressionMatch match = reName.match(line);
            if (match.hasMatch()) {
                currentMonitor.name = match.captured(1).trimmed();
                qDebug() << "Monitor name:" << currentMonitor.name;
            }
        }
    }

    // Add the last monitor if we have one
    if (!currentMonitor.id.isEmpty()) {
        monitors[currentMonitor.id] = currentMonitor;
    }

    qDebug() << "After parsing, found" << monitors.size() << "monitors";

    return monitors;
}

bool DDCUtilInterface::setBrightness(const QString& monitorId, int brightness)
{
    if (!m_isAvailable) {
        return false;
    }

    // Clamp brightness to 0-100
    brightness = qBound(0, brightness, 100);

    // Get current brightness before changing
    int currentBrightness = getBrightness(monitorId);

    QString output = executeCommand("ddcutil", QStringList()
                                  << "--bus" << monitorId
                                  << "setvcp" << "10" << QString::number(brightness));

    // If we can't get the output or the command failed, return false
    if (output.isEmpty()) {
        return false;
    }

    // Verify the change by checking if brightness is now closer to requested value
    // Some monitors might not set to the exact value we request
    int newBrightness = getBrightness(monitorId);

    // If we can't read the new brightness, consider it a failure
    if (newBrightness < 0) {
        return false;
    }

    // Consider success if the brightness changed in the right direction
    // or is now equal to what we requested
    bool movedInRightDirection =
        (brightness > currentBrightness && newBrightness > currentBrightness) ||
        (brightness < currentBrightness && newBrightness < currentBrightness) ||
        (brightness == newBrightness);

    return movedInRightDirection;
}

int DDCUtilInterface::getBrightness(const QString& monitorId)
{
    if (!m_isAvailable) {
        return -1;
    }

    QStringList args;
    args << "--bus" << monitorId << "getvcp" << "10";
    QString output = executeCommand("ddcutil", args);

    if (output.isEmpty()) {
        return -1;
    }

    QRegularExpression reBrightness("current value\\s*=\\s*(\\d+)");
    QRegularExpressionMatch match = reBrightness.match(output);

    if (match.hasMatch()) {
        return match.captured(1).toInt();
    }

    return -1;
}
