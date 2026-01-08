-- Этап 1. Создание и заполнение БД

CREATE SCHEMA raw_data; -- создаём схему с сырыми данными

DROP TABLE IF EXISTS raw_data.sales CASCADE; -- предварительно удаляем таблицу, если она была ранее создана

CREATE TABLE IF NOT EXISTS raw_data.sales (
	id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	auto VARCHAR(255) NOT NULL, -- название по сути представляет собой текстовую информацию небольшого объёма, следовательно выбираем тип Varchar
	gasoline_consumption NUMERIC(5,2), -- тип Numeric был выбран исходя из имеющихся данных в файле
	price NUMERIC(10,2) NOT NULL, -- тип Numeric обеспечивает точность цены
	date DATE NOT NULL, -- в скачанном файле указана дата без времени, следовательно нам не нужен тип Timestamp, достаточно Date
	person_name VARCHAR(255) NOT NULL, -- выбран тип Varchar с ограничением, поскольку невозможно записать продажу без отражение имени контрагента
	phone VARCHAR(50) NOT NULL, -- важнейший контакт контрагента, запишем его в формате Varchar с ограничением Not Null
	discount SMALLINT NOT NULL, -- цена указана в процентах, а с точки зрения таблицы это целое число, следовательно берем тип Smallint
	brand_origin VARCHAR(20) -- прочую текстовую информацию также будем записывать в формате Varchar
	);

\copy raw_data.sales FROM 'sales_data.csv' WITH CSV HEADER DELIMITER ',' NULL AS ''; -- импортируем данные из файла в таблицу sales (с заголовками)
-- Также здесь прописано, что Null-значения приравниваются к прочерку.

CREATE SCHEMA IF NOT EXISTS car_shop; -- создаём схему с обновлёнными данными

-- Убрал ссылку на ID бренда.
CREATE TABLE IF NOT EXISTS car_shop.cars ( -- справочник автомобилей (сюда попадают уникальные транспортные средства)
	car_id SERIAL PRIMARY KEY, -- применяем суррогатный ключ - неуникальное сочетание ID модели и ID цвета (ведь может быть сколько угодно одинаковых машин)
	model_id INTEGER REFERENCES car_shop.models(model_id), -- ссылка на ID модели
	color_id INTEGER REFERENCES car_shop.colors(color_id) -- ссылка на ID цвета
	);

CREATE TABLE IF NOT EXISTS car_shop.brands ( -- справочник брендов с привязкой к странам происхождения
	brand_id SERIAL PRIMARY KEY, -- ID бренда (выбираем автоматический)
	brand_name VARCHAR(20) NOT NULL, -- текстовая информация (20 символов вполне достаточно)
	origin_country_id INTEGER REFERENCES car_shop.countries(country_id) -- ссылка на ID страны
	);

-- Добавил столец с расходом топлива без ограничения Not Null.
CREATE TABLE IF NOT EXISTS car_shop.models ( -- справочник моделей машин с привязкой к бренду (а точнее к ID бренда)
	model_id SERIAL PRIMARY KEY, -- ID модели (выбираем автоматический)
	brand_id INTEGER REFERENCES car_shop.brands (brand_id), -- ссылка на ID бренда
	model_name VARCHAR(50) NOT NULL, -- текстовая информация (50 символов достаточно)
	gasoline_consumption NUMERIC(5,2) -- расход топлива (есть пропуски, поэтому не ставим ограничение Not Null)
	);

CREATE TABLE IF NOT EXISTS car_shop.countries ( -- справочник стран-производителей автомобилей
	country_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	country_name VARCHAR(20) NOT NULL -- текстовая информация (необходимо наличие этих данных, иначе смысл теряется)
	);

CREATE TABLE IF NOT EXISTS car_shop.colors ( -- данные о возможных цветах
	color_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	color_name VARCHAR(255) NOT NULL -- текстовая информация
	);

CREATE TABLE IF NOT EXISTS car_shop.clients ( -- справочник контрагентов
	client_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	person_name VARCHAR(255) NOT NULL, -- текстовая информация (необходимо наличие этих данных)
	phone VARCHAR(255) NOT NULL, -- текстовая информация (контакт контрагента обязателен, поэтому ставим ограничение Not Null)
	);

-- Убрал ID страны и расход топлива во избежание появления противоречащей информации.
-- Исправил ссылку на ID автомобиля, чтобы не потерять иформацию о цвете проданной машины (название столбца изменил).
CREATE TABLE IF NOT EXISTS car_shop.sales ( -- обновлённая таблица продаж
	deal_id SERIAL PRIMARY KEY, -- первичный ключ - ID сделки
	car_id INTEGER REFERENCES car_shop.cars(car_id), -- ссылка на ID конкретного автомобиля (информация о бренде, модели и цвете будет в справочнике cars)
	price NUMERIC(10,2) NOT NULL, -- цена с заданной точностью (берём в сырых данных)
	deal_date date NOT NULL DEFAULT current_date, -- дата сделки (там же)
	client_id INTEGER REFERENCES car_shop.clients(client_id), -- ID клиента
	discount SMALLINT -- скидка в процентах, уместен тип Smallint (снова их сырых данных)
	);

-- изменил порядок заполнения таблиц, чтобы не возникало ошибок при выполнении скрпита

INSERT INTO car_shop.brands (brand_name) -- заполняем справочник брендов
SELECT DISTINCT SPLIT_PART(rds.auto, ' ', 1) AS brand_name -- первое слово в столбце auto - это название бренда
FROM raw_data.sales rds;

INSERT INTO car_shop.colors (color_name) -- заполняем справочник цветов
SELECT DISTINCT SUBSTR(rds.auto, STRPOS(rds.auto, ',') + 2) AS color_name -- ищем уникальные названия цветов, убирая марки машин до запятой и пробела
FROM raw_data.sales rds;

INSERT INTO car_shop.countries (country_name) -- заполняем справочник стран
SELECT DISTINCT rds.brand_origin -- ищем уникальные страны
FROM raw_data.sales rds;

-- Исправил на уникальные сочетания бренда, модели и расхода топлива.
-- Интересно, может ли расход топлива быть неуникальным?
INSERT INTO car_shop.models (brand_id, model_name, gasoline_consumption) -- заполняем справочник моделей с привязкой к ID бренда (модель - второе слово в строке из столбца auto)
SELECT DISTINCT b.brand_id, SPLIT_PART(rds.auto, ' ', 2) AS model_name, rds.gasoline_consumption -- ищем сочетания ID бренда и имени модели (ей будет автоматически присвоен свой ID)
FROM raw_data.sales rds -- из таблицы сырых данных
JOIN car_shop.brands b ON SPLIT_PART(s.auto, ' ', 1) = b.brand_name; -- "достаём" ID бренда, соединив таблицы

-- Убрал упоминание бренда, добавил условие Distinct.
INSERT INTO car_shop.cars (model_id, color_id) -- заполняем перечень выпущенных автомобилей с указанием бренда, модели и цвета (их ID)
SELECT DISTINCT m.model_id, col.color_id -- собираем воедино уникальные комбинации ID бренда и ID модели
FROM raw_data.sales rds -- из сырых данных
JOIN car_shop.models m ON SPLIT_PART(rds.auto, ' ', 2) = m.model_name -- из таблицы models забираем ID модели
JOIN car_shop.colors col ON SPLIT_PART(rds.auto, ' ', -1) = col.color_name -- из таблицы colors забираем ID цвета

-- Решил оставить справочник клиентов в таком же виде (имена и фамилии разделены)
INSERT INTO car_shop.clients (first_name, last_name) -- заполняем справочник контрагентов, разделив имена и фамилии по отдельным полям
SELECT DISTINCT SPLIT_PART(person_name, ' ', 1) AS first_name, SPLIT_PART(person_name, ' ', -1) AS last_name -- нужны уникальные сочетания имени и фамилии 
FROM raw_data.sales;

-- Здесь пришлось поправить джоины. Добавилась строчка с присоединением справочника car_shop.cars.
INSERT INTO car_shop.sales (car_id, price, deal_date, client_id, discount) -- заполняем факты продаж
SELECT c.car_id, rds.price, rds.deal_date, cl.client_id, rds.discount -- проставляем соответствующие значения в нужные столбцы
FROM raw_data.sales rds -- за основу берём таблицу с сырыми данными
JOIN car_shop.models m ON SPLIT_PART(rds.auto, ' ', 2) = m.model_name -- получаем ID модели, соединив сырые данные по второму слову в столбце auto с названием модели из таблицы car_shop.models
JOIN car_shop.cars c ON m.model_id = c.model_id -- от моделей переходим к машинам, соединив таблицы через ID модели
JOIN car_shop.clients cl ON SPLIT_PART(rds.person_name, ' ', 1) = cl.first_name AND SPLIT_PART(rds.person_name, ' ', -1) = cl.last_name -- получаем ID клиента, соединив имена из сырых данных со справочником клиентов (имена и фамилии разделены)

-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

SELECT -- считаем количество с помощью Case и вычисляем долю в процентах
  (COUNT(DISTINCT CASE WHEN gasoline_consumption IS NULL THEN auto END) / COUNT(DISTINCT auto)) * 100 AS nulls_percentage_gasoline_consumption
FROM car_shop.sales; -- из обновлённой таблицы продаж

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT
	SUBSTR(auto, 1, STRPOS(auto, ' ', -1)) as brand_name, -- самое первое слово в столбце auto
	ROUND(AVG(price)) AS price_avg, -- усредняем цену
	EXTRACT(YEAR FROM date) AS year -- выделяем года и дат
FROM car_shop.sales -- из обновлённой таблицы продаж
GROUP BY brand_name, EXTRACT(YEAR FROM date); -- делаем группировку по машинам и разбиение по годам

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT
	EXTRACT (MONTH FROM date) AS month, -- выделяем месяцы аналогично предыдущему примеру
	EXTRACT (YEAR FROM date) AS year, -- теперь годы
	ROUND(AVG(price)) AS price_avg -- аналогичный расчёт средней цены
FROM car_shop.sales -- из обновлённой таблицы продаж
WHERE date::date BETWEEN '2022-01-01' AND '2022-12-31' -- указываем верхнюю и нижнюю границы дат, предварительно изменив тип данных в столбце date на Date
GROUP BY EXTRACT (MONTH FROM date), EXTRACT (YEAR FROM date) AS year; -- разбиваем по месяцам

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT
	person_name as person,
	STRING_AGG(auto, ', ') AS cars -- соединяем все машины одного владельца в список через запятую
FROM car_shop.sales -- из обновлённой таблицы продаж
GROUP BY person -- формируем перечень транспортных средств, закреплённых за клиентами
ORDER BY person; -- для удобства чтения делаем сортировку клиентов по алфавиту

---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.

SELECT
	DISTINCT brand_origin, -- ищем уникальные страны
	MAX(price / (1 - discount / 100)) AS price_max, -- ищем наибольшую цену (изменён расчёт цены)
	 MIN(price / (1 - discount / 100)) AS price_min -- ищем наименьшую цену (изменён расчёт цены)
FROM car_shop.sales -- из обновлённой таблицы продаж
GROUP BY brand_origin -- группируем по странам

---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.

SELECT
	COUNT(DISTINCT person_name) AS persons_from_usa_count -- количество уникальных клиентов из США
FROM car_shop.sales -- из обновлённой таблицы продаж
WHERE SUBSTR(phone, 1, 2) = '+1' -- фильтр по коду страны в телефоне
