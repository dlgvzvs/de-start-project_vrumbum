-- Этап 1. Создание и заполнение БД

CREATE SCHEMA raw_data;

DROP TABLE IF EXISTS raw_data.sales CASCADE;

CREATE TABLE IF NOT EXISTS raw_data.sales (
	id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	auto VARCHAR(255) NOT NULL, -- название по сути представляет собой текстовую информацию небольшого объёма, следовательно выбираем тип Varchar
	gasoline_consumption NUMERIC(5,2), -- тип Numeric был выбран исходя из имеющихся данных в файле
	price NUMERIC(10,2) NOT NULL, -- тип Numeric обеспечивает точность цены
	date DATE NOT NULL, -- в скачанном файле указана дата без времени, следовательно нам не нужен тип Timestamp, достаточно Date
	person_name VARCHAR(255) NOT NULL, -- выбран тип Varchar с ограничением, поскольку невозможно записать продажу без отражение имени контрагента
	phone VARCHAR(50) NOT NULL, -- важнейший контакт контрагента, запишем его в формате Varchar с ограничением Not Null
	discount SMALLINT NOT NULL, -- цена указана в процентах, а с точки зрения таблицы это целое число, следовательно берем тип Smallint
	brand_origin TEXT -- прочую текстовую информацию также будем записывать в формате Text
	);

\copy raw_data.sales FROM 'sales_data.csv' WITH CSV HEADER DELIMITER ','; -- импортируем данные из файла в таблицу sales из схемы raw_data с указанием, что здесь есть заголовки, а также дополнительно прописываем раздлитель - запятую

CREATE SCHEMA IF NOT EXISTS car_shop;

CREATE TABLE IF NOT EXISTS car_shop.cars ( -- данные об автомобилях
	car_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	brand_name VARCHAR(255) NOT NULL, -- текстовая информация
	);

CREATE TABLE IF NOT EXISTS car_shop.colors ( -- данные о возможных цветах
	color_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	color_name VARCHAR(255) NOT NULL -- текстовая информация
	);

CREATE TABLE IF NOT EXISTS car_shop.cars_colors ( -- группировка автомобилей по цветам, при этом одна и та же модель автомобиля может быть представлена в разных цветах
	color_id INTEGER REFERENCES car_shop.colors(color_id), -- ссылаемся на ID из другой таблицы, значит нужен тип Integer
    car_id INTEGER REFERENCES car_shop.cars(car_id), -- ссылаемся на ID из другой таблицы, значит нужен тип Integer
    PRIMARY KEY (color_id, car_id)
	);

CREATE TABLE IF NOT EXISTS car_shop.clients ( -- справочник контрагентов
	client_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	first_name VARCHAR(255) NOT NULL, -- текстовая информация (необходимо наличие этих данных)
	last_name VARCHAR(255) NOT NULL, -- текстовая информация (необходимо наличие этих данных)
	company_name VARCHAR(255), -- текстовая информация
	work_address TEXT, -- текстовая информация
	phone VARCHAR(255) NOT NULL, -- текстовая информация (контакт контрагента обязателен, поэтому ставим органичение Not Null)
	email TEXT, -- текстовая информация (телефона будет достаточно, поэтому здесь ограничение решено не ставить)
	personal_discount SMALLINT REFERENCES raw_data.sales (discount) -- копируем скидку в таком же формате - Smallint
	);
	
CREATE TABLE IF NOT EXISTS car_shop.countries ( -- справочник стран-производителей автомобилей
	country_id SERIAL PRIMARY KEY, -- для ID самым удобным является тип данных Serial, он убирает необходимость вручную проставлять номер
	country_name VARCHAR(255) NOT NULL -- текстовая информация (необходимо наличие этих данных, иначе смысл теряется)
	);

CREATE TABLE IF NOT EXISTS car_shop.cars_by_origin_countries ( -- группировка автомобилей по странам производства
	country_id INTEGER REFERENCES car_shop.countries (country_id), -- ссылаемся на ID из другой таблицы, значит нужен тип Integer
	car_id INTEGER REFERENCES car_shop.cars (car_id)-- ссылаемся на ID из другой таблицы, значит нужен тип Integer
	);

INSERT INTO car_shop.cars (brand_name) -- заполняем справочник автомобилей без учёта цветов
SELECT DISTINCT SUBSTR(auto, 1, STRPOS(auto, ',') - 1) AS brand_name -- извлекаем название, исключив цвета (они отделены запятой с пробелом)
FROM raw_data.sales;

INSERT INTO car_shop.colors (color_name) -- заполняем справочник цветов
SELECT DISTINCT SUBSTR(auto, STRPOS(auto, ',') + 2) AS color_name -- ищем уникальные названия цветов, убирая марки машин до запятой и пробела
FROM raw_data.sales;

INSERT INTO car_shop.cars_colors (color_id, car_id) -- прописываем, какие марки машин в каких цветах представлены
SELECT col.color_id, ca.car_id -- в таблицу пойдут не имена цветов и машин, а их ID
FROM raw_data.sales
JOIN car_shop.colors AS col ON SUBSTR(sales.auto, STRPOS(auto, ',') + 2) = col.color_name -- фрагмент текста после запятой из столбца auto в таблице sales совпадает с названием цвета в таблице colors
JOIN car_shop.cars AS ca ON SUBSTR(auto, 1, STRPOS(auto, ',') - 1) = ca.brand_name; -- фрагмент текста до запятой из столбца auto в таблице sales совпадает в маркой машины из таблицы cars

INSERT INTO car_shop.clients (first_name, last_name) -- заполняем справочник контрагентов, разделив имена и фамилии по отдельным полям
SELECT DISTINCT SPLIT_PART(person_name, ' ', 1) AS first_name, SPLIT_PART(person_name, ' ', -1) AS last_name -- нужны уникальные сочетания имени и фамилии
FROM raw_data.sales;

INSERT INTO car_shop.countries (country_name) -- заполняем справочник стран
SELECT DISTINCT brand_origin -- ищем уникальные страны
FROM raw_data.sales;

INSERT INTO car_shop.cars_by_origin_countries (country_id, car_id) -- проставляем соответствие марки машины стране происхождения
SELECT co.country_id, ca.car_id -- в таблицу пойдут не названия стран и машин, а их ID
FROM raw_data.sales
JOIN car_shop.countries AS co ON sales.brand_origin = co.country_name -- соответствие названий стран
JOIN car_shop.cars AS ca ON SUBSTR(sales.auto, 1, STRPOS(sales.auto, ',') - 1) = ca.brand_name; -- соответствие марок машин

-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

SELECT -- считаем количество с помощью Case и вычисляем долю в процентах
  (COUNT(DISTINCT CASE WHEN gasoline_consumption IS NULL THEN auto END) / COUNT(DISTINCT auto)) * 100 AS nulls_percentage_gasoline_consumption
FROM raw_data.sales;

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT
	SUBSTR(auto, 1, STRPOS(auto, ' ', -1)) as brand_name, -- самое первое слово в столбце auto
	ROUND(AVG(price * (1 - discount / 100)), 2) AS price_avg, -- усредняем цену и скидку, получая цену со скидкой с округлением до 2 знаков после запятой
	EXTRACT(YEAR FROM date) AS year -- выделяем года и дат
FROM raw_data.sales
GROUP BY brand_name, EXTRACT(YEAR FROM date); -- делаем группировку по машинам и разбиение по годам

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT
	EXTRACT (MONTH FROM date) AS month, -- выделяем месяцы аналогично предыдущему примеру
	EXTRACT (YEAR FROM date) AS year, -- теперь годы
	ROUND(AVG(price * (1 - discount / 100)), 2) AS price_avg -- аналогичный расчёт средней цены со скидкой
FROM raw_data.sales
WHERE date::date BETWEEN '2022-01-01' AND '2022-12-31' -- указываем верхнюю и нижнюю границы дат, предварительно изменив тип данных в столбце date на Date
GROUP BY EXTRACT (MONTH FROM date), EXTRACT (YEAR FROM date) AS year; -- разбиваем по месяцам

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT
	person_name as person,
	STRING_AGG(auto, ', ') AS cars -- соединяем все машины одного владельца в список через запятую
FROM raw_data.sales
GROUP BY person -- формируем перечень транспортных средств, закреплённых за клиентами
ORDER BY person; -- для удобства чтения делаем сортировку клиентов по алфавиту

---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.

SELECT
	DISTINCT brand_origin, -- ищем уникальные страны
	MAX(price) AS price_max, -- ищем наибольшую цену
	MIN(price) AS price_min -- ищем наименьшую цену
FROM raw_data.sales
GROUP BY brand_origin -- группируем по странам
ORDER BY brand_origin -- для удобства чтения делаем сортировку стран по алфавиту

---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.

SELECT
	COUNT(DISTINCT person_name) AS persons_from_usa_count -- количество уникальных клиентов из США
FROM raw_data.sales
WHERE SUBSTR(phone, 1, 2) = '+1' -- фильтр по коду страны в телефоне
