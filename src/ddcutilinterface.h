#ifndef DDCUTILINTERFACE_H
#define DDCUTILINTERFACE_H

#include <QObject>
#include <QProcess>
#include <QMap>
#include <QString>
#include <QStringList>

class DDCUtilInterface : public QObject
{
    Q_OBJECT

public:
    explicit DDCUtilInterface(QObject *parent = nullptr);
    ~DDCUtilInterface();

    struct MonitorInfo {
        QString id;
        QString name;
        QString manufacturer;
        int currentBrightness;
        int maxBrightness;
    };

    bool isAvailable() const;
    QList<MonitorInfo> detectMonitors();
    bool setBrightness(const QString& monitorId, int brightness);
    int getBrightness(const QString& monitorId);

private:
    bool checkDDCUtilInstalled();
    QString executeCommand(const QString& command, const QStringList& arguments);
    QMap<QString, MonitorInfo> parseDetectOutput(const QString& output);

    bool m_isAvailable;
};

#endif // DDCUTILINTERFACE_H
