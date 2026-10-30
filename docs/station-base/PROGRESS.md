# Station Base v1 — checkpoints

Исходная точка: b0c901161ed97f7964b5921fbdc3f3ace94a498d. Ветка feature/station-base-v1. Все параметры относятся к технической совместимости v106, а не к реальным размерам Малиновки.

## Этап 1. Модульные контракты

Созданы StationDefinition, TrainCompatibilityProfile, TrackModule, PlatformModule, TrainStopModule, TunnelConnector, CollisionModule, PassengerStationContract, DecorationInterface и Validation. Геометрические значения централизованы в data/station-base/v106.js. Выход модулей — данные, независимые от Three.js.

Проверка: node --test tests/station-base.test.js — 6/6. Включены отрицательные сценарии: слишком короткая платформа, неподдерживаемая конфигурация, неправильная высота рельса/двери, несовпадающий порт. Проверено сохранение мировых координат для всех 16 дверей при смене пространства.

Это промежуточный checkpoint: 3D-просмотрщик и проверка фактических mesh ещё не реализованы. Обход колёс должен читать batchedParts, а не исчезающие userData.wheel. Данные пассажиров остаются контрактом, без PassengerSystem. Ни один существующий игровой/поездной файл не изменён.
