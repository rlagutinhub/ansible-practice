docker
======
Роль для установки docker
## Описание некоторых переменных
```yaml
# YAML-словарь, преобразуемый в файл /etc/docker/daemon.json
# Ниже представлено значение по-умолчанию:
docker_daemon_json:
  graph: "/var/lib/docker"
  live-restore: true
  log-driver: "json-file"
  log-opts:
    max-file: "4"
    max-size: "10m"
  storage-driver: "overlay2"
# Также часто используются некоторые другие опции:
  iptables: false
  insecure-registries:
    - "192.0.2.0/24"
    - "198.51.100.15:5000"
  dns:
    - "203.0.113.30"
  dns-search:
    - "marathon.mesos"

docker_gc_cron_time: string # default: "00 02 * * *": расписание крона для очистки более ненужных образов

docker_monit_la5: string        # default: берётся из роли base: порог средней загрузки за 5 минут, после которого запускается хайлоад-репорт
docker_monit_la15: string       # default: берется из роли base: то же самое, но загрузка за 15 минут. Сейчас никак не используется

docker_pstree_cron_time: string # default: "* * * * *": расписание крона для запуска docker-pstree.sh (статистика для docker-oom-report.sh, который запускается из monit-а при сообщениях о oom-killer-е в контейнерах)

docker_package_name: string     # default: "ce", варианты: "ce","engine": какой вариант докера ставить. Engine давно устарел, не использовать

docker_iptables_enable: bool # default: false: создавать ли цепочку правил SB.docker, производящую фильтрацию перед штатными, закрывает доступ к контейнерам снаружи
docker_iptables_public_interface: string # default: "UNDEF": внешний интерфейс, входящий трафик которого будет фильтроваться цепочкой. Требуется если цепочка включена
docker_iptables_permit_list: ipv4/cide   # default: указан ниже: список ipv4/cidr, трафик с которых не убивается в цепочке, а идёт на штатные правила. Трафик с других адресов будет отброшен цепочкой
  - 127.0.0.0/8
```
## Зависимости
-
