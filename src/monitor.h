#ifndef MONITOR_H
#define MONITOR_H

#include <QObject>
#include <QString>

class Monitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString displayName READ displayName CONSTANT)
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool controllable READ isControllable CONSTANT)

public:

    explicit Monitor(QObject *parent = nullptr);
    explicit Monitor(const QString& id, const QString& name, const QString& manufacturer,
                    int brightness, int maxBrightness, QObject *parent = nullptr);

    QString id() const;
    QString displayName() const;
    int brightness() const;
    bool isControllable() const;

public slots:
    void setBrightness(int brightness);
    void refresh();

signals:
    void brightnessChanged(int brightness);
    void brightnessUpdateFailed();

private:
    QString m_id;
    QString m_name;
    QString m_manufacturer;
    int m_brightness;
    int m_maxBrightness;
    bool m_controllable;
};

#endif // MONITOR_H
