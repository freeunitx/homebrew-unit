# 🩺 План: bottle-подсистема FreeUnit в GitHub Packages

## 🧬 1. Цель

Перенести отработанную bottle-подсистему `shivammathur/homebrew-php`. Сохранить независимую сборку FreeUnit в `.github/workflows/manual.yml`.

Homebrew будет скачивать готовые бутылки вместо сборки из исходников. GHCR будет хранить архивы Homebrew в формате OCI. Docker-образ FreeUnit для этого не нужен.

Страница пакетов форка:

<https://github.com/freeunitx?tab=packages&repo_name=homebrew-unit>

Страница пакетов upstream после переноса:

<https://github.com/orgs/freeunitorg/packages?repo_name=homebrew-unit>

## 🩻 2. Архитектура

Используем проверенную цепочку образца:

```text
PR → build → checks → artifacts → build-complete
                              ↓
              publish-commit-bottles.yml
                              ↓
                    GHCR + bottle do
```

`manual.yml` остается отдельной полной сборкой FreeUnit. Он не участвует в публикации пакетов.

Публикация находится только в отдельном `publish-commit-bottles.yml`. Сборочные workflows не получают `packages: write`.

### Соответствие файлов

| Файл FreeUnit | Назначение |
|---|---|
| `.github/workflows/main.yml` | Сборка PR, проверки и артефакты бутылок |
| `.github/workflows/manual.yml` | Независимая полная сборка FreeUnit |
| `.github/workflows/dispatch-build-bottle.yml` | Ручная сборка выбранной формулы |
| `.github/workflows/dispatch-rebottle.yml` | Ручная пересборка бутылок |
| `.github/workflows/publish-commit-bottles.yml` | Публикация после успешных проверок |
| `.github/workflows/autopublish.yml` | Автоматический запуск публикации после настройки |
| `.github/workflows/actionlint.yml` | Actionlint и Zizmor в CI |
| `.github/scripts/environment.js` | Параметры раннеров и `test-bot` |
| `.github/scripts/retry.sh` | Повтор команды для `gh pr merge` |
| `.github/zizmor.yml` | Правила Zizmor |

Инфраструктуру `build.yml` переносим в существующий `main.yml`. Отдельный `build.yml` не нужен. Два одинаковых `test-bot` в каждом PR не нужны.

## 💉 3. Что переносим без изменений в логике

Из `homebrew-php` переносим следующие механизмы:

- `Homebrew/actions/pre-build` и `Homebrew/actions/post-build`;
- `brew test-bot --only-json-tab` с `--root-url`;
- артефакты `bottles_*`;
- метку `build-complete` после успешной сборки;
- `brew pr-pull` для публикации после проверок;
- `Homebrew/actions/git-user-config`;
- `Homebrew/actions/git-try-push`.

Версии действий фиксируем. Адреса `@main` из образца не копируем без фиксации.

Образец отличается от нашего tap в одном месте. В homebrew-php matrix содержит только ОС. Одна задача собирает все формулы PR. У нас matrix содержит ОС и формулу. Поэтому аргументы `test-bot` и имена артефактов должны зависеть от формулы задачи. Копировать вызов `post-build` и `environment.js` из образца без этой правки нельзя.

## 🚑 4. Что не переносим

Не переносим части, которые не относятся к bottle-подсистеме:

- `create-pr` и PHP-скрипт `edit.sh`;
- PHP-матрицу версий и варианты `debug` или `zts`;
- `bump.yml`;
- `test.yml` с `shivammathur/setup-php`;
- `sync-default-branches.yml` с force-push;
- правки Homebrew через `sudo sed`;
- раннеры, которые недоступны проекту.

Сохраняем наши формулы, зависимости и проверки. Образец задает инфраструктуру, а не правила сборки FreeUnit.

## 🧪 5. Этап 1: адаптируйте main.yml

Перенесите сборочную часть `build.yml` в текущий `main.yml`.

### Сохраните текущие проверки

- [ ] Сохраните `check-generate` и определение измененных формул.
- [ ] Сохраните развертывание зависимостей через `case` для `unit`, `php-embed` и модулей.
- [ ] Сохраните имена заданий, которые использует branch protection.
- [ ] Сохраните `fail-fast: false`.
- [ ] Сохраните проверку `test-bot.log` на скрытые ошибки.
- [ ] Не используйте `--fail-fast` как замену этой проверки.

### Добавьте инфраструктуру бутылок

- [ ] Добавьте `BOTTLES_DIR` в задание `build-formulae`.
- [ ] Добавьте `Homebrew/actions/pre-build` перед `brew test-bot`.
- [ ] Добавьте `Homebrew/actions/post-build` с `if: always()`.
- [ ] Добавьте `--only-json-tab` к аргументам `test-bot`.
- [ ] Добавьте `--root-url` с адресом GHCR.
- [ ] Сохраняйте журналы и бутылки как артефакты.
- [ ] Добавьте поле `artifact` в каждый элемент matrix. Поле содержит ОС и имя формулы без tap. Замените символы вне `[A-Za-z0-9._-]` на `-`.
- [ ] Передайте `runner: ${{ matrix.artifact }}` в `post-build`. Действие называет артефакты `logs_${runner}` и `bottles_${runner}`. Одинаковые имена в задачах одной ОС дают ошибку повторной записи.
- [ ] Читайте список формул в генерации matrix построчно: `tr ',' '\n'`. `--only-formulae-detect` пишет имена в одну строку через запятую.

Используйте переменные окружения из образца:

```yaml
env:
  HOMEBREW_DEVELOPER: "1"
  HOMEBREW_GITHUB_ACTIONS: "1"
  HOMEBREW_NO_AUTO_UPDATE: "1"
  HOMEBREW_RELOCATABLE_INSTALL_NAMES: "1"
```

### Адаптируйте раннеры

Используйте доступные проекту платформы:

```text
ubuntu-24.04
macos-15
macos-26
```

Для Linux используйте контейнер `ghcr.io/homebrew/brew:main` по образцу. Не переносите `xcode-27` и `macos-15-arm64` без подтверждения доступности.

### Добавьте build-complete

Добавьте отдельное задание `label` после успешной сборки. Оно ставит метку `build-complete`.

- [ ] Дайте заданию только `contents: read` и `pull-requests: write`.
- [ ] Не давайте заданию `packages: write`.
- [ ] Ставьте метку только после зеленых сборок и проверки журнала.
- [ ] Для upstream проверьте права токена на PR из форка.
- [ ] Если GitHub запрещает запись метки, пусть maintainer ставит ее вручную.

## 🧬 6. Этап 2: адаптируйте environment.js

Перенесите `.github/scripts/environment.js` из образца.

Сохраните полезные метки CI и генерацию аргументов `test-bot`. Удалите специальные правила для PHP, которые не применимы к FreeUnit.

Вычисляйте адрес из данных репозитория:

```javascript
const tapName = context.repo.repo.replace(/^homebrew-/, '')
const rootUrl = `https://ghcr.io/v2/${context.repo.owner}/${tapName}`
```

Для форка результат:

```text
https://ghcr.io/v2/freeunitx/unit
```

Для upstream результат:

```text
https://ghcr.io/v2/freeunitorg/unit
```

- [ ] Не оставляйте `shivammathur/php` в аргументах.
- [ ] Не передавайте `--testing-formulae` в общих аргументах. Шаг сборки каждой задачи matrix добавляет `--testing-formulae` со своей формулой и зависимостями из этого tap (`case`, как в `main.yml` до переноса). Общий список заставляет каждую задачу собирать все формулы PR.
- [ ] Используйте `ubuntu-24.04` вместо недоступных раннеров.
- [ ] Сохраните текущий список формул из `check-generate`.
- [ ] Не копируйте матрицу всех версий PHP из образца.

## 💊 7. Этап 3: добавьте ручные сборки

Создайте два файла по образцу:

- `dispatch-build-bottle.yml`;
- `dispatch-rebottle.yml`.

Они нужны для сборки формулы без ожидания следующего изменения PR.

### dispatch-build-bottle.yml

Добавьте параметры `runner`, `formula` и `timeout`. Сохраните `pre-build`, `test-bot` и `post-build`.

### dispatch-rebottle.yml

Добавьте параметры `formula`, `timeout` и `fail-fast`. Используйте нашу матрицу ОС.

### Общие правила

- [ ] Используйте `ROOT_URL` нашего tap.
- [ ] Разверните зависимости формулы, как в `main.yml`: `unit-php@<серия>` собирается вместе с `php-embed@<серия>` и `unit`, другой модуль — вместе с `unit`. Homebrew не имеет бутылок для них.
- [ ] Запускайте dispatch на ветке PR (`gh workflow run … --ref <ветка PR>`). `brew pr-pull` ищет run по HEAD PR. Run на другой ветке не подходит.
- [ ] Добавьте проверку `test-bot.log` в оба workflow.
- [ ] Сохраняйте артефакты `bottles_*`.
- [ ] Не публикуйте пакеты прямо из этих workflows.
- [ ] Передавайте артефакты в отдельный `publish-commit-bottles.yml`.

Так вся публикация будет сосредоточена в одном файле.

## 🏥 8. Этап 4: создайте отдельный publish-commit-bottles.yml

Создайте `.github/workflows/publish-commit-bottles.yml` по образцу `homebrew-php`.

Этот файл запускается после успешных проверок. Только он получает право записи в GitHub Packages.

### Входные параметры

```yaml
on:
  workflow_dispatch:
    inputs:
      pull_request:
        description: Pull request number
        required: true
      workflow:
        description: Workflow that produced the bottles
        required: true
        default: main.yml
```

Параметр `workflow` принимает:

- `main.yml`;
- `dispatch-build-bottle.yml`;
- `dispatch-rebottle.yml`.

### Права

```yaml
permissions:
  actions: write
  contents: write
  packages: write
  pull-requests: write
```

### Обязательная проверка перед публикацией

Добавьте отдельное задание `precheck` до загрузки бутылок.

- [ ] Проверьте, что PR открыт.
- [ ] Запустите `gh pr checks "${PR}"`.
- [ ] Проверьте наличие метки `build-complete` только для `main.yml`. Метку ставит только `main.yml`. Dispatch workflows ее не ставят. Для них проверку делают run и артефакты.
- [ ] Выберите последний завершенный run выбранного workflow для HEAD PR. Требуйте `success`. `brew pr-pull` берет артефакты из последнего run. Старый успешный run рядом с новым провальным не подходит.
- [ ] Передайте `run-id` и `head-sha` этого run в задание `upload`.
- [ ] Проверьте наличие артефактов `bottles_*` в этом run.
- [ ] Остановите публикацию при любой ошибке.

Публикация не должна зависеть только от ручного выбора PR. Workflow обязан сам проверить зеленые результаты.

### Публикация

После `precheck` запустите задание `upload`. Используйте:

```yaml
env:
  HOMEBREW_GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  HOMEBREW_GITHUB_PACKAGES_USER: ${{ github.repository_owner }}
  HOMEBREW_GITHUB_PACKAGES_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Вызов для нашего `main.yml`:

```bash
brew pr-pull \
  --debug \
  --clean \
  --workflows="${WORKFLOW}" \
  --tap="${TAP}" \
  --root-url="${ROOT_URL}" \
  --head-sha="${HEAD_SHA}" \
  "${PR}"
```

`HEAD_SHA` задание `upload` берет из `precheck`. Перед вызовом `upload` повторяет выбор последнего завершенного run. При несовпадении с `run-id` из `precheck` публикация останавливается. `--head-sha` останавливает `brew pr-pull` при смене HEAD PR.

`brew pr-pull` скачивает артефакты, загружает бутылки и добавляет `bottle do`.

- [ ] Настройте Git через `Homebrew/actions/git-user-config`.
- [ ] Включите **Settings → General → Pull Requests → Allow auto-merge** до первого запуска. `gh pr merge --auto` без этой настройки не работает. Для upstream настройку включает maintainer.
- [ ] Перенесите безопасные шаги merge и push из образца.
- [ ] Используйте `Homebrew/actions/git-try-push` для записи формул.
- [ ] Не переносите синхронизацию веток.
- [ ] Не используйте `sudo sed`.
- [ ] Проверьте, что коммит содержит только ожидаемые изменения.

## 🩹 9. Этап 5: добавьте autopublish.yml

Создайте `autopublish.yml` по образцу после успешной ручной публикации.

Он выбирает открытые PR с меткой `build-complete` и зелеными проверками `gh pr checks`. Для каждого PR он запускает `publish-commit-bottles.yml` через `gh workflow run`. Публикация идет через тот же отдельный файл с тем же `precheck`. `brew pr-automerge --publish` не используется: он не проверяет run и артефакты.

- [ ] Сначала отключите расписание.
- [ ] Проверьте ручной запуск `autopublish.yml`.
- [ ] Проверьте повторную проверку зеленых результатов в `publish-commit-bottles.yml`.
- [ ] Включите расписание только после успешной проверки.
- [ ] Не включайте автоматическое объединение чужих PR без доверенной проверки.

## 🧪 10. Этап 6: проверьте первую публикацию

Первую проверку выполните в форке с формулой `unit`.

### Сборка

- [ ] Создайте PR в `freeunitx/master`.
- [ ] Проверьте успешное завершение `main.yml`.
- [ ] Проверьте отсутствие скрытых ошибок `test-bot`.
- [ ] Проверьте наличие бутылок в артефактах.
- [ ] Проверьте метку `build-complete`.
- [ ] Проверьте отсутствие пакетов GHCR до публикации.

Если PR меняет только workflows, матрица формул может быть пустой. Для первой бутылки используйте `dispatch-build-bottle.yml` с `formula=unit`. Запустите его на ветке PR:

```bash
gh workflow run dispatch-build-bottle.yml --ref <ветка PR> -f formula=unit -f runner=ubuntu-24.04
```

### Публикация

- [ ] Запустите `Publish and commit bottles` с номером PR.
- [ ] Для ручной сборки укажите `workflow=dispatch-build-bottle.yml`. Метка `build-complete` для этого пути не нужна.
- [ ] Проверьте успешный `precheck`.
- [ ] Проверьте пакет `unit/unit` в GHCR.
- [ ] Проверьте `bottle do` в `Formula/unit.rb`.
- [ ] Проверьте `root_url` и контрольные суммы.

## 🏥 11. Этап 7: настройте пакет GitHub

Откройте настройки пакета после первой публикации.

- [ ] Если пакет создан приватным, установите `Visibility: Public`.
- [ ] Подключите `freeunitx/homebrew-unit` через `Connect repository`.
- [ ] Проверьте пакет на странице <https://github.com/freeunitx?tab=packages&repo_name=homebrew-unit>.
- [ ] Проверьте анонимный доступ к манифесту GHCR.

Пакет без связи с репозиторием может не попасть в фильтр `repo_name=homebrew-unit`.

Ожидаемые имена пакетов:

| Формула | Пакет GHCR |
|---|---|
| `unit` | `unit/unit` |
| `unit-php@8.4` | `unit/unit-php/8.4` |
| `php-embed@8.4` | `unit/php-embed/8.4` |

## 🩺 12. Этап 8: расширьте список бутылок

После проверки `unit` добавляйте формулы группами:

1. `php-embed`, `php-embed@8.5`, `php-embed@8.4`, `php-embed@8.3`.
2. `unit-php`, `unit-php@8.5`, `unit-php@8.4`, `unit-php@8.3`.
3. `unit-perl`, `unit-python3`, `unit-java`, `unit-ruby`, `unit-wasm`.

- [ ] Проверьте совпадение серии PHP между модулем и библиотекой.
- [ ] Проверьте контрольные суммы для каждой ОС.
- [ ] Сохраните текущий порядок зависимостей формул.
- [ ] Не собирайте разные `php-embed` в один общий prefix без unlink.
- [ ] Оставьте `manual.yml` независимой проверкой сборки из исходников.
- [ ] Обновите `README.md` адресом Packages и списком платформ.
- [ ] Обновите `CHANGES.md` после рабочей публикации.

## 🧪 13. Проверка результата

### Локальные проверки

- [ ] Запустите `docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test`.
- [ ] Запустите `python3 test/check-components-order.py Formula`.
- [ ] Actionlint и Zizmor запускает `actionlint.yml` в CI. Они не проверяют состав matrix, имена артефактов и выбор run. Зеленые линтеры не доказывают готовность.
- [ ] Сделайте dry-run скрипта генерации matrix и шага сборки с заглушкой `brew` на двух формулах: `unit` и `unit-php@8.4`.
- [ ] Если изменились PHP-формулы, запустите проверки inreplace и patches.

### Проверки GitHub

- [ ] Проверьте артефакты каждой формулы и ОС.
- [ ] Проверьте, что каждая задача matrix собирает только свою группу формул.
- [ ] Проверьте отсутствие `packages: write` в сборочных workflows.
- [ ] Проверьте остановку `precheck` при красных проверках.
- [ ] Проверьте остановку `precheck` без артефактов.
- [ ] Проверьте остановку `precheck` без `build-complete` для `main.yml`.
- [ ] Проверьте остановку `precheck`, когда последний run провален, а прошлый успешен.
- [ ] Проверьте публикацию только из отдельного файла.
- [ ] Проверьте публичную видимость и связь пакета с репозиторием.
- [ ] Включите **Allow auto-merge** в настройках репозитория.

### Проверка установки

- [ ] Установите формулу в чистом контейнере без токена GHCR.
- [ ] Не используйте `--build-from-source` при этой проверке.
- [ ] Проверьте строку `Pouring` в журнале Homebrew.
- [ ] Запустите тест формулы после установки.
- [ ] Запустите `brew linkage --test` после установки.

## 🚑 14. Откат при ошибке

Не удаляйте пакет GHCR как первое действие. Удаление может нарушить установку старых версий формулы.

- [ ] Если бутылка не работает, откройте PR.
- [ ] Удалите неправильный `bottle do`.
- [ ] Проверьте возврат к сборке из исходников.
- [ ] Исправьте формулу или сборку.
- [ ] Опубликуйте новую бутылку через `publish-commit-bottles.yml`.
- [ ] Если пакет приватный по ошибке, измените только его видимость.

## 💉 15. Перенос в upstream

- [ ] Проверьте весь процесс в `freeunitx/homebrew-unit`.
- [ ] Создайте PR из `freeunitx` в `freeunitorg/master`.
- [ ] Не используйте учетную запись `phpclub`.
- [ ] Попросите maintainer upstream объединить PR.
- [ ] Попросите maintainer запустить отдельный publish workflow.
- [ ] Проверьте корень `https://ghcr.io/v2/freeunitorg/unit`.
- [ ] Подключение пакетов к `freeunitorg/homebrew-unit` выполняет maintainer upstream.

До публикации в upstream пакеты будут принадлежать только `freeunitx`. Права форка не дают доступ к пакетам организации `freeunitorg`.

## ✅ 16. Критерии завершения

- [ ] Bottle-подсистема использует проверенную цепочку `homebrew-php`.
- [ ] `manual.yml` остается независимой сборкой FreeUnit.
- [ ] `main.yml` создает проверенные артефакты бутылок.
- [ ] Имена артефактов уникальны для каждой формулы и ОС.
- [ ] Каждая задача matrix собирает только свою группу формул.
- [ ] Публикация находится только в `publish-commit-bottles.yml`.
- [ ] Публикация запускается после зеленых проверок.
- [ ] Публикация берет артефакты run, который проверил `precheck`.
- [ ] Сборочные workflows не имеют `packages: write`.
- [ ] Пакет `unit/unit` публичен и связан с `freeunitx/homebrew-unit`.
- [ ] `Formula/unit.rb` содержит правильный `bottle do`.
- [ ] Чистый контейнер устанавливает бутылку без авторизации.
- [ ] Локальные проверки проходят.
