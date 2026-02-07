# Smart Light

Монорепозиторий для управления сервоприводами через ESP32, с бекендом на Nitro и фронтендом на Flutter.
Данное мобильное приложение позволяет управлять системой освещения (модуль светодиодов, сервоприводы). Ниже представлен сценарий использования мобильного приложения.

<img width="347" height="212" alt="изображение" src="https://github.com/user-attachments/assets/345112e7-3a5d-4a11-b7d7-0118de696624" />

API приложения:
| Путь | Метод | Назначение |
|------|-------|------------|
| `/` | ANY | Главный эндпоинт |
| `/_ws` | ANY | WebSocket соединение |
| `/health` | GET | Проверка состояния сервиса |
| `/devices` | GET | Получить список всех устройств |
| `/devices/online` | GET | Получить список устройств в сети |
| `/devices/:id` | GET | Получить устройство по ID |
| `/devices/:id` | PUT | Обновить устройство по ID |
| `/devices/:id` | DELETE | Удалить устройство по ID |
| `/devices/:id/status` | GET | Получить статус устройства |
| `/devices/:id/led` | POST | Управление светом устройства |
| `/devices/:id/servo` | GET | Получить состояние сервопривода |
| `/devices/:id/servo` | POST | Управление сервоприводами |
| `/_openapi.json` | ANY | OpenAPI (Swagger) спецификация |
| `/_scalar` | ANY | Scalar UI для просмотра OpenAPI |

Более подробно с мобильным приложениям можно ознакомиться ниже:
<img width="259" height="351" alt="изображение" src="https://github.com/user-attachments/assets/5d21403a-a8c3-4eb5-b599-d5a691439bd1" />
<img width="290" height="193" alt="изображение" src="https://github.com/user-attachments/assets/3a10c73d-6bf5-46cb-9fae-d707d95944f9" />
<img width="208" height="303" alt="изображение" src="https://github.com/user-attachments/assets/8c53e72f-a0d4-4d41-a437-63101aa459da" />
<img width="194" height="313" alt="изображение" src="https://github.com/user-attachments/assets/5a8332cb-970d-4767-aba1-be46f6642e7d" />

Пример рабочего устройства:

<img width="225" height="301" alt="изображение" src="https://github.com/user-attachments/assets/7ae5c681-5d60-4135-9cfe-1f4fa5c3230b" />
