# Linux: базовые вопросы


### 1. Как посмотреть процессы в Linux

- **`ps aux`** — все процессы всех пользователей с информацией о CPU, памяти, PID.
- **`top` / `htop`** — интерактивный мониторинг процессов в реальном времени.
- **`ps -ef | grep <имя>`** — поиск конкретного процесса.
- **`pidof <имя>`** — получить PID процесса по имени.

```bash
# все процессы, отсортированные по использованию памяти
ps aux --sort=-%mem | head -20

# интерактивный мониторинг (top)
top -p <PID>        # следить за конкретным процессом
htop                # более наглядный интерфейс
```

### 2. Как узнать, какие порты слушаются

- **`ss -tlnp`** — TCP-порты в статусе LISTEN с PID процесса (рекомендуется, замена устаревшего `netstat`).
- **`netstat -tlnp`** — то же самое (устаревший, но часто встречается).
- **`lsof -i :<порт>`** — какой процесс слушает конкретный порт.

```bash
# все слушающие TCP-порты
ss -tlnp

# конкретный порт (например, 8080)
ss -tlnp | grep 8080
lsof -i :8080

# UDP-порты
ss -ulnp
```

### 3. Как проверить использование диска

- **`df -h`** — свободное место на всех смонтированных файловых системах (human-readable).
- **`du -sh <путь>`** — размер каталога/файла (summarize, human-readable).
- **`du -sh *`** — размеры всех содержимых текущей директории.

```bash
# свободное место
df -h

# размер конкретного каталога
du -sh /var/log
du -sh /home/user

# найти большие файлы (>100M)
find / -type f -size +100M 2>/dev/null
```

### 4. Как найти файл по имени или содержимому

- **`find <путь> -name "<имя>"`** — поиск по имени (поддерживает `*` и `?`).
- **`grep -rn "<текст>" <путь>`** — поиск по содержимому файлов (рекурсивно, с номерами строк).
- **`locate <имя>`** — быстрый поиск по базе `updatedb` (может быть устаревшей).

```bash
# найти файл по имени
find / -name "application.yaml" 2>/dev/null
find . -name "*.log" -mtime +7   # логи старше 7 дней

# найти по содержимому
grep -rn "ERROR" /var/log/
grep -r "password" /etc/
```

### 5. Как управлять правами доступа

- **`chmod <права> <файл>`** — изменить права (r=4, w=2, x=1).
- **`chown <пользователь>:<группа> <файл>`** — изменить владельца и группу.
- **`ls -la`** — посмотреть текущие права.

```bash
# чтение + запись для владельца, чтение для остальных
chmod 644 config.yaml

# исполняемый скрипт
chmod +x script.sh
chmod 755 deploy.sh

# сменить владельца
chown app:app /app/data
```

### 6. Как настроить сетевое подключение

- **`ip addr`** — IP-адреса интерфейсов (замена `ifconfig`).
- **`ip route`** — таблица маршрутов.
- **`ping <хост>`** — проверка доступности.
- **`curl <url>`** — проверка HTTP(S)-запроса.
- **`nc <хост> <порт>`** (netcat) — проверка TCP-подключения.

```bash
# IP-адреса
ip addr
ip a

# маршруты
ip route

# проверка подключения
ping -c 4 google.com
curl -v https://example.com
nc -zv db.example.com 5432   # порт открыт?
```

### 7. Как настроить Cron Job

**Cron** — планировщик задач. Формат записи в `/etc/crontab` или `crontab -e`:

```
┌──────── минута (0-59)
│ ┌────── час (0-23)
│ │ ┌──── день месяца (1-31)
│ │ │ ┌── месяц (1-12)
│ │ │ │ ┌── день недели (0-6, 0=Вс)
│ │ │ │ │
* * * * * команда
```

```bash
# открыть cron текущего пользователя
crontab -e

# посмотреть существующие cron
crontab -l

# примеры:
0 2 * * *   /usr/bin/backup.sh          # каждый день в 02:00
*/15 * * * * /usr/bin/cleanup.sh        # каждые 15 минут
0 0 * * 0   /usr/bin/weekly_report.sh   # каждую субботу в 00:00
```

### 8. Как посмотреть логи системных сервисов

- **`journalctl`** — логи systemd (syslog-заменитель).
- **`journalctl -u <сервис>`** — логи конкретного сервиса.
- **`journalctl -f`** — tail в реальном времени.
- **`/var/log/syslog`** или **`/var/log/messages`** — файлы логов (зависит от дистрибутива).

```bash
# логи systemd
journalctl -u nginx
journalctl -u postgresql

# последние 50 строк
journalctl -u app --no-pager -n 50

# за последний час
journalctl --since "1 hour ago"

# tail в реальном времени
journalctl -f -u app

# поиск ошибок
journalctl -p err -u app
```

### 9. Как создать и настроить сервис в systemd

**systemd** — init-система, управляющая процессами. Файл юнита лежит в `/etc/systemd/system/`.

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/myapp
Restart=on-failure
Environment="JAVA_OPTS=-Xmx512m"

[Install]
WantedBy=multi-user.target
```

```bash
# применить изменения
systemctl daemon-reload

# управление сервисом
systemctl start myapp
systemctl stop myapp
systemctl restart myapp
systemctl status myapp

# автозапуск при старте
systemctl enable myapp
systemctl disable myapp
```

### 10. Как настроить firewall

**Firewalld** (RHEL/CentOS) или **UFW** (Ubuntu).

```bash
# === UFW (Ubuntu) ===
ufw status
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 10.0.0.0/8 to any port 3306
ufw enable

# === Firewalld (RHEL) ===
firewall-cmd --list-all
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload

# посмотреть правила
firewall-cmd --list-ports
```

### 11. Как настроить SSH-ключи

```bash
# сгенерировать пару ключей
ssh-keygen -t ed25519 -C "user@host"
# (или rsa -t 4096 для старых серверов)

# скопировать публичный ключ на сервер
ssh-copy-id user@server

# или вручную:
cat ~/.ssh/id_ed25519.pub | ssh user@server "cat >> ~/.ssh/authorized_keys"

# настроить ~/.ssh/config
Host myserver
    HostName 192.168.1.100
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    Port 22
```

### 12. Как отладить сетевые проблемы

```bash
# DNS
nslookup example.com
dig example.com
dig @8.8.8.8 example.com

# маршрутизация
traceroute example.com
mtr example.com          # мониторинг в реальном времени

# TCP handshake
ss -tlnp | grep <порт>
netstat -an | grep ESTABLISHED

# пропускная способность
iperf3 -s               # сервер
iperf3 -c <хост>        # клиент

# проверка HTTP-заголовков
curl -I https://example.com
curl -v https://example.com
```

### 13. Как диагностировать проблему с OOM (Out of Memory)

**OOM** — процесс убит, потому что исчерпал выделенную память. Ядро Linux пишет в dmesg и journal.

```bash
# 1. Проверить, был ли OOM-kill (dmesg)
dmesg | grep -i "oom\|killed"

# 2. Посмотреть в journal
journalctl --since "1 hour ago" | grep -i "oom"

# 3. Найти PID убитого процесса
journalctl -k | grep "Killed process"

# 4. Посмотреть текущее использование памяти
free -h
cat /proc/meminfo

# 5. Найти процессы с максимальным потреблением
ps aux --sort=-%mem | head -10

# 6. Посмотреть лимиты cgroups (Docker/к8s)
cat /sys/fs/cgroup/memory.max          # cgroup v2
cat /sys/fs/cgroup/memory/memory.limit_in_bytes  # cgroup v1

# 7. Мониторинг в реальном времени
watch -n 1 "free -h"
```

**Типичные причины:**
- Недостаточный `-Xmx` (Java) — процесс растёт до лимита cgroup
- Утечка памяти (memory leak)
- Слишком много процессов одновременно
- Swap исчерпан, ядро выбирает жертву по `oom_score`

### 14. Как найти процесс, потребляющий много CPU

```bash
# 1. Посмотреть топ по CPU
top -o %CPU | head -15
ps aux --sort=-%cpu | head -10

# 2. Следить за конкретным процессом
top -p <PID>
htop -p <PID>

# 3. Посмотреть, что делает процесс (стек вызовов)
eu-stack -p <PID>          # eu-stack из elfutils
pstack <PID>               # если установлен

# 4. Для Java: thread dump
jstack <PID> > /tmp/thread_dump.txt
jstack <PID> | grep -A 20 "main"

# 5. Посмотреть, в каком состоянии процесс (R, S, D, Z)
ps -o pid,state,comm -p <PID>
# R = running, S = sleeping, D = disk wait, Z = zombie

# 6. Проверить, не в ли deadlock (для Java)
jstack <PID> | grep -i "deadlock"
```

### 15. Как диагностировать зависший процесс (D-state, deadlock)

**D-state** (uninterruptible sleep) — процесс ждёт I/O и не реагирует на сигналы.

```bash
# 1. Найти процессы в D-state
ps aux | awk '$8 ~ /D/'

# 2. Посмотреть, на что ждёт процесс
cat /proc/<PID>/wchan
cat /proc/<PID>/stack

# 3. Посмотреть открытые файловые дескрипторы
ls -la /proc/<PID>/fd/
lsof -p <PID>

# 4. Для Java: thread dump
jstack <PID>

# 5. Проверить, не заблокирован ли на диске
iostat -x 1 3
iotop -p <PID>

# 6. Если процесс в deadlock — нужно перезапустить (SIGKILL не поможет при D-state)
```

### 16. Как проверить, нет ли утечки файловых дескрипторов

**File descriptor (fd) leak** — процесс открывает файлы/сокеты и не закрывает их.

```bash
# 1. Посмотреть лимит fd для процесса
cat /proc/<PID>/limits | grep "open files"

# 2. Посчитать открытые fd
ls /proc/<PID>/fd/ | wc -l

# 3. Посмотреть, что открыто (файлы, сокеты)
ls -la /proc/<PID>/fd/

# 4. Найти конкретные сокеты
lsof -p <PID> | grep -i socket

# 5. Посмотреть, сколько сокетов в TIME_WAIT
ss -tnp | grep TIME_WAIT | wc -l

# 6. Проверить лимиты системы
cat /proc/sys/fs/file-max
sysctl fs.file-max
```

**Типичные причины утечки fd:**
- Не закрытые файлы/сокеты
- Connection pool без лимита
- Забытый `close()` в исключении

### 17. Как диагностировать проблему с диском (I/O bottleneck)

```bash
# 1. Посмотреть загрузку дисков
iostat -x 1 5
# %util > 80% — диск загружен
# await > 10ms — высокие задержки

# 2. Найти процессы, читающие/пишущие на диск
iotop
iotop -o -p <PID>

# 3. Посмотреть, какие файлы активно используются
lsof +D /var/log/ 2>/dev/null

# 4. Проверить свободное место
df -h
df -i  # inode

# 5. Найти крупные файлы, которые могут быть причинами
du -sh /var/log/*
find / -type f -size +1G 2>/dev/null

# 6. Проверить здоровье диска (smart)
smartctl -a /dev/sda
```

### 18. Как настроить логи для отладки (log levels, buffering)

```bash
# 1. Увеличить уровень логирования (для Java Spring Boot)
# В application.yaml:
logging.level.com.myapp=DEBUG

# Через环境变量:
export LOGGING_LEVEL_COM_MYAPP=DEBUG

# 2. Посмотреть логи в реальном времени
tail -f /var/log/myapp/app.log
journalctl -f -u myapp

# 3. Найти ошибки за определённый период
grep "ERROR" /var/log/myapp/app.log | grep "2024-01-15"

# 4. Структурированные логи (JSON)
jq '.level == "ERROR"' /var/log/myapp/app.json

# 5. Отладка без перезапуска (Java)
# JMX console или arthas:
logset -d com.myapp -l DEBUG
```

### 19. Как проверить, работает ли процесс (health check)

```bash
# 1. Проверить, что процесс жив
ps -p <PID>

# 2. HTTP health check
curl -f http://localhost:8080/actuator/health
curl -f http://localhost:8080/health

# 3. Проверить, что порт слушается
nc -zv localhost 8080

# 4. Для Docker:
docker ps | grep <имя>
docker inspect <контейнер> | grep -i health

# 5. Для Kubernetes:
kubectl get pods -n <namespace>
kubectl describe pod <pod> | grep -A 5 "Liveness"
kubectl exec <pod> -- curl -f http://localhost:8080/health

# 6. Проверить, что процесс не zombie
ps aux | awk '$8 == "Z" {print $2, $11}'
```

### 20. Как настроить мониторинг процессов (systemd, Prometheus)

```ini
# /etc/systemd/system/monitor.service
[Unit]
Description=Process Monitor
After=network.target

[Service]
Type=simple
User=monitor
ExecStart=/opt/monitor/bin/check_processes.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
#!/bin/bash
# check_processes.sh
# Проверка, что ключевые процессы работают
for proc in nginx postgresql redis; do
  if ! pgrep -x "$proc" > /dev/null; then
    echo "[$(date)] ALERT: $proc is down" | logger
    # Отправить уведомление (email, slack)
    curl -X POST -d "{\"text\":\"$proc down\"}" https://hooks.slack.com/services/XXX
  fi
done
```

**Прометей + node_exporter:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

# Метрики:
# node_cpu_seconds_total
# node_memory_MemAvailable_bytes
# node_filesystem_avail_bytes
```

### 21. Как найти и исправить permission denied

```bash
# 1. Посмотреть права на файл
ls -la /path/to/file

# 2. Посмотреть, кто владелец
stat /path/to/file

# 3. Исправить права (только если нужно!)
chmod +x /path/to/script.sh
chown app:app /path/to/file

# 4. Проверить, нет ли ACL
getfacl /path/to/file

# 5. Для SELinux (RHEL/CentOS):
ls -Z /path/to/file
chcon -R -u system_u -r object_r -t httpd_sys_content_t /var/www/html
restorecon -Rv /var/www/html

# 6. Проверить, не заблокирован ли файрволом
iptables -L -n | grep <порт>
```

### 22. Как отладить проблему с таймаутами (timeout)

```bash
# 1. Посмотреть, где происходит timeout
curl -v --max-time 30 http://localhost:8080/api

# 2. Проверить, что порт открыт и отвечает быстро
time nc -zv localhost 8080
time curl http://localhost:8080/health

# 3. Посмотреть, нет ли сетевых проблем
ping -c 4 localhost
mtr localhost

# 4. Проверить, не исчерпаны ли connection pool
ss -tnp | grep ESTABLISHED | wc -l
ss -tnp | grep <порт> | wc -l

# 5. Для Java: посмотреть thread dump (блокировки)
jstack <PID> | grep -A 5 "BLOCKED"

# 6. Проверить, нет ли медленных запросов в БД
# PostgreSQL:
SELECT pid, state, query_start, query FROM pg_stat_activity WHERE state = 'active' ORDER BY query_start LIMIT 10;
```

### 23. Как настроить алерты на проблемы

```yaml
# Prometheus Alertmanager
alert_rules:
  - alert: HighCPU
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]) * 100)) > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"

  - alert: MemoryLow
    expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Low memory on {{ $labels.instance }}"

  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "{{ $labels.job }} is down"
```


