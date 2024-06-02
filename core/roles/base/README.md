## base

Обязательная для всех хостов роль. Управляет основными настройками
системы, наполняет /srv/southbridge и делает настройку по нашим
стандартам. Работает ТОЛЬКО с redhat-системами, сейчас 6 и 7.
Устанавливает/настраивает etckeeper/iptables/monit/slack...

### Переменные

```yaml
base_atop_enable: bool # default: true: записывать ли статистику работы с помощью atop-а. Обычно требуется выключать чтобы сэкономить диск

## HOSTS
base_etc_hosts_common: list # default: undefined: маппинг произвольных fqdn через /etc/hosts
 - { ipaddr: 'ipv4', fqdn: 'host.example.com' }

base_etc_hosts_local: list # default: undefined: маппинг имён машин клиента через /etc/hosts. Для ipaddr добавляются имена host и host.example.com (берётся host и добавляется второй и далее элементы из ansible_nodename)
  - { ipaddr: 'ipv4', host: 'string' }
##

## IPTABLES
base_iptables_enable: bool # default: true: включать ли сервис пакетного фильтра sb-iptables-base, управляющий цепочкой правил SB.base
# По умолчанию в SB.base разрешены: zabbix_server/vs40.sb/vs05.sb/ansible_ssh_proxy
# Основной сервис iptables включается безусловно. Он может
# интегрироваться с ролью nat через её переменные либо же задавать
# цепочку nat переменной iptables_additional_nat_rules

iptables_additional_rules: list # default: []: список дополнительных строк-правил для цепочки INPUT таблицы filter, например "-A INPUT -s 192.168.0.0/24 -j ACCEPT"
iptables_base_tcp_ports: string # default: "111,2812,48022,10050,5900:5910": какие tcp порты направлять в SB.base
iptables_base_udp_ports: string # default: "111,123,161": какие udp порты направлять в SB.base
base_sb_iptables_extra_list: list # default: []: список дополнительных хостов которые разрешены в цепочке SB.base
##

base_ipv4_forward_enable: bool # default: false: включить "net.ipv4.ip_forward" (vds и vs)

base_ipv6: bool # default: false: оставлять ли поддержку ipv6. Пока почти ничего не делает (#278465)

base_journald_options: # default указан ниже: параметры для /etc/systemd/journald.conf
  Storage: 'persistent'
  Compress: 'yes'

## MONIT
base_monit_la5: '__LA5__' # порог высокой загрузки для monit. Дефолт ориентирован на наш пакет monit, который подставит значение по ядрам процессора
base_monit_la15: '__LA15__' # порог высокой загрузки для docker-проверки monit
##

## NTP
base_ntpd_enable: bool # default: true: сконфигурировать и запустить сервис ntpd
base_ntpdate_enable: bool # default: true: делать периодический ntpdate если не включена предыдущая переменная (выключите если используете нестандартный демон синхронизации)
base_ntp_pool: string # default: de.pool.ntp.org: настроить ntpd на серверы 0,1,2,3.base_ntp_pool
base_ntp_custom_servers: list # default: undefined: список IP/fqdn ntp-серверов. Заменяет base_ntp_pool если определён
  - string
##

## RESOLV.CONF
base_leave_resolvconf: bool # default: false: не трогать resolv.conf
base_resolv_conf: list # default: []: строчки для наполнения resolv.conf (целиком) . По умолчанию наполняется гуглом/яндесом, плюс лупбэком для не-ds
base_use_public_resolvers: bool # default: true: использовать публичные резольверы (8.8.8.8 и т. д.)

##

base_packages_additional: list # default: []: опциональный список пакетов, которые нужно установить

base_static_route: # default: undefined: добавить статичные маршруты в /etc/sysconfig/network-scripts/route-<dev>,
  - dev: "device_name" # ...а также "на лету" в таблицу маршрутизации (или удалить их)
    routes:
      - { dest: "CIDR", gw: "ipv4_address"[, src 'ipv4', metric 'int', state: bool] }
      - ...

base_sysctl_user_vars: # Пользовательские параметры ядра, ключи разделяются точкой
  key: value

base_sysfs_user_vars: # Параметры для записи в /sys без этого префикса, ключи разделяются точкой или слешем, например:
  kernel.mm.transparent_hugepage.enabled: never
  kernel/mm/transparent_hugepage/defrag:  never

base_systemd_options: # Параметры для /etc/systemd/system.conf
  LogLevel: 'notice'

base_yum_exclude: list # default: []: список пакетов-исключений в /etc/yum.conf, директива exclude
  - string

## SERVICES
disabled_services_local: [] # опциональный дополнительный список сервисов для останова/выключения
enabled_services_local: [] # опциональный дополнительный список сервисов для старта/включения. При пересечении с предыдущей переменной имеет приоритет (выполняется позже)
##

## LIMITS
ds_soft_procs: int # default: 16384: мягкий лимит на процессы всех пользователей ds
ds_hard_procs: int # default: undefined: жесткий лимит процессов всех пользователей ds
vs_soft_procs: int # default: 4096: мягкий лимит на процессы всех пользователей vs
vs_hard_procs: int # default: undefined: жесткий лимит процессов всех пользователей vs
##

timezone: string # default: Europe/Moscow: таймзона для сервера
```

### Зависимости

* `init-variables` (вызывается автоматически через include_role)
