USE 365_database;

-- 	Look at all tables
SELECT *
FROM 365_course_info;

SELECT *
FROM 365_course_ratings;

SELECT *
FROM 365_student_info;

SELECT *
FROM 365_student_learning;

SELECT *
FROM 365_student_purchases;

SELECT *
FROM 365_student_info;


-- Retrive courses information
-- `course_id` – the unique identification of a course
-- `course_title` – the title of the course
-- `total_minutes_watched` – all minutes watched from the course for the entire period
-- `average_minutes` – all minutes watched from the course for the entire period divided by the number of students who’ve started the course
-- `number_of_ratings` – the number of ratings the course has received
-- `average_rating` – the sum of all the course's ratings divided by the number of students who rated it.
WITH title_minutes AS(
	SELECT
		ci.course_id,
        ci.course_title,
		ROUND(SUM(sl.minutes_watched),2) AS total_minutes_watched,
        ROUND(SUM(sl.minutes_watched)/COUNT(DISTINCT sl.student_id),2) AS average_minutes
	FROM 365_course_info ci
	JOIN 365_student_learning sl
    ON ci.course_id = sl.course_id
    GROUP BY 1, 2
),
title_ratings AS(
	SELECT
		tm.course_id,
        tm.course_title,
		tm.total_minutes_watched,
        tm.average_minutes,
        COUNT(cr.course_rating) AS number_of_ratings,
        IF(COUNT(cr.course_rating)!=0, ROUND(SUM(cr.course_rating)/COUNT(cr.course_rating),2), 0) AS average_rating
	FROM title_minutes tm
    LEFT JOIN 365_course_ratings cr
    ON tm.course_id = cr.course_id
    GROUP BY 1, 2
)
SELECT *
FROM title_ratings;



-- Retrive purchases information
-- `purchase_id`
-- `student_id`
-- `purchase_type`
-- `date_start` (the date the subscription started)
-- `date_end` (the date the subscription ended)
DROP VIEW IF EXISTS purchases_info; 

CREATE VIEW purchases_info AS    -- Create a view for the next task
	SELECT
		purchase_id,
		student_id,
		purchase_type,
		date_purchased AS date_start,
		CASE purchase_type
			WHEN 'Monthly' THEN DATE_ADD(date_purchased, INTERVAL 1 MONTH)
			WHEN 'Quarterly' THEN DATE_ADD(date_purchased, INTERVAL 3 MONTH)
			WHEN 'Annual' THEN DATE_ADD(date_purchased, INTERVAL 12 MONTH)
			ELSE NULL
		END AS date_end
	FROM 365_student_purchases;


-- Retrive students information
-- `student_id` – a list of student IDs
-- `student_country` – the country of origin they’ve entered into the platform
-- `date_registered` – registration date of the students
-- `date_watched` – the date they’ve watched a course
-- `minutes_watched` – the minutes they’ve watched from that course on that day
-- `onboarded` – whether they have a record in the 365_student_learning table (0 – no, 1 – yes) 
-- `paid` – whether they’ve had an active subscription on the day of watching the course (0 – no, 1 – yes)
WITH onboarded_students_watching_history AS(
	SELECT 	
		si.student_id,
        si.student_country,
        si.date_registered,
        sl.date_watched,
        IF(sl.student_id IS NULL, 0, ROUND(SUM(sl.minutes_watched),2)) AS minutes_watched,
		IF(sl.student_id IS NULL, 0, 1) AS onboarded
    FROM 365_student_info si
    LEFT JOIN 365_student_learning sl
    ON si.student_id = sl.student_id
    GROUP BY 1, 4
),
subscription_status AS(
	SELECT
		wh.*,
        IF(wh.date_watched BETWEEN pi.date_start AND pi.date_end, 1, 0) AS paid
	FROM onboarded_students_watching_history wh
	LEFT JOIN purchases_info pi
    ON wh.student_id = pi.student_id
)
SELECT
	student_id,
    student_country,
    date_registered,
    date_watched,
    minutes_watched,	
    onboarded,
    MAX(paid) AS paid
FROM subscription_status
GROUP BY 1, 4;