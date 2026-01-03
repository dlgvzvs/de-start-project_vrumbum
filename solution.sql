-- Этап 1. Создание и заполнение БД
CREATE SCHEMA raw_data;
DROP TABLE IF EXISTS raw_data.sales CASCADE;
CREATE TABLE IF NOT EXISTS raw_data.sales (
	id SERIAL PRIMARY KEY,
	auto TEXT NOT NULL,
	gasoline_consumption NUMERIC(10,2),
	price NUMERIC(10,2) NOT NULL,
	`date` DATE,
	person_name TEXT NOT NULL,
	phone TEXT NOT NULL,
	discount INTEGER,
	brand_origin TEXT
	);

\copy sales FROM 'sales_data.csv' WITH CSV HEADER;

CREATE TABLE IF NOT EXISTS raw_data.cars (
	car_id SERIAL PRIMARY KEY,
	brand_name TEXT NOT NULL,
	);

CREATE TABLE IF NOT EXISTS raw_data.cars_colors (
	color_id INT REFERENCES raw_data.colors(color_id),
    car_id INT REFERENCES raw_data.cars(car_id),
    PRIMARY KEY (color_id, car_id)
);

CREATE TABLE IF NOT EXISTS raw_data.colors (
	color_id SERIAL PRIMARY KEY,
	color_name TEXT NOT NULL
	);
-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.



---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.



---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.



---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.



---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.




