CREATE DATABASE car_database;

use car_database;

select * from cars;

DROP TABLE IF EXISTS forum_topics;

CREATE TABLE forum_topics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO forum_topics (topic, description) VALUES
('General Car Discussion', 'A place to talk about cars in general.'),
('Electric Vehicles', 'Discussion about electric cars and their technology.'),
('Hybrid Cars', 'Chat about hybrid vehicles and how they work.'),
('Car Maintenance', 'Share tips and advice on maintaining your car.'),
('Car Modifications', 'Talk about car mods and customization.'),
('Classic Cars', 'For fans of vintage and classic cars.'),
('Motorsports', 'Discuss the latest news and events in motorsports.'),
('Car Buying Advice', 'Get and give advice on buying cars.'),
('Off-Road Vehicles', 'Discuss 4x4s and off-road adventures.'),
('Luxury Cars', 'Chat about luxury and high-end cars.'),
('Eco-Friendly Cars', 'Talk about environmentally friendly car technologies.');

select * from forum_topics;

CREATE TABLE cars (
    id INT AUTO_INCREMENT PRIMARY KEY,
    year INT NOT NULL,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    body_type JSON NOT NULL
);


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.0/Uploads/2000.csv'
INTO TABLE cars
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(year, make, model, @body_type)
SET body_type = REPLACE(@body_type, '""', '');

SHOW VARIABLES LIKE 'secure_file_priv';

select * from cars;


CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

drop table users;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

select * from users;