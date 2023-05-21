USE employees_mod;

-- KBQ1: how many female and male employees working as manager in different departments since 1990
SELECT t1.manager, MAX(t1.manager_gender) gender, t1.dept_name, t1.years years from
(SELECT 
    m.emp_no AS manager,
    e.gender AS manager_gender,
    d.dept_name AS dept_name,
    YEAR(dm.from_date) AS years,
    CASE WHEN YEAR(dm.from_date) BETWEEN YEAR(m.from_date) AND YEAR(m.to_date) THEN 1 ELSE 0 END AS activity
FROM
    t_dept_manager m
        LEFT JOIN
    t_departments d ON m.dept_no = d.dept_no
        LEFT JOIN
    t_employees e ON e.emp_no = m.emp_no
        CROSS JOIN
    t_dept_emp dm ON dm.dept_no = m.dept_no
WHERE YEAR(dm.from_date) >= 1990
HAVING activity = 1) t1
GROUP BY years, manager, dept_name
ORDER BY years;

-- The solution with procedure and loop
DROP TABLE IF EXISTS dept_managers_gender_since_1990;
CREATE TABLE dept_managers_gender_since_1990 
	(manager INT, 
	gender ENUM('m','f'), 
	dept_name VARCHAR(50), 
	years INT);
	
DROP PROCEDURE IF EXISTS departments_managers_gender;
DELIMITER $$
create procedure departments_managers_gender()
BEGIN
DECLARE a INT;
SET a = 1990;
the_loop: LOOP
		INSERT INTO dept_managers_gender_since_1990 
		SELECT m.emp_no AS manager, 
			e.gender AS manager_gender, 
			d.dept_name AS dept_name, a
		FROM t_dept_manager m 
			LEFT JOIN t_departments d ON m.dept_no = d.dept_no 
			LEFT JOIN t_employees e ON e.emp_no = m.emp_no
		WHERE a BETWEEN YEAR(m.from_date) AND YEAR(m.to_date);
	SET a = a + 1;
    	IF a < 2003 THEN
		iterate the_loop;
	ELSE 
		LEAVE the_loop;
	END IF;
END LOOP;
END $$
DELIMITER ;
CALL departments_managers_gender();
SELECT * FROM dept_managers_gender_since_1990;


-- KBQ2: Male salary vs female salary until 2002 per department
-- first creating a table for calender years
CREATE TABLE years (calender_year DATE);
drop procedure if exists years_;
delimiter $$
create procedure years_()
Begin
	declare a date;
    	set a = '1990-01-01';
    	the_loop: LOOP
		INSERT INTO years VALUES (a);
        	SET a = a + INTERVAL 1 YEAR;
        		IF a > '2002-12-29' THEN
					LEAVE the_loop;
			ELSE iterate the_loop;
        	END IF;
	END LOOP;
END $$
delimiter ;
call years_();
select * from years;

WITH CTE AS (
SELECT e.gender gender, 
	s.salary salary,
	s.from_date, 
	s.to_date, 
	d.dept_name dept_name, 
	y.calender_year calender_year
FROM t_salaries s 
	LEFT JOIN t_employees e ON e.emp_no = s.emp_no
	LEFT JOIN t_dept_emp de ON de.emp_no = s.emp_no
	LEFT JOIN t_departments d ON d.dept_no = de.dept_no
CROSS JOIN years y
WHERE e.gender is not null
AND y.calender_year between s.from_date AND s.to_date)
	SELECT gender, 
		AVG(salary), 
		dept_name, 
		YEAR(calender_year) 
	FROM CTE
	GROUP BY dept_name, gender, calender_year;


-- If we have the salary contract for each year in salary table then we can use this shorter query
SELECT e.gender, 
	d.dept_name, 
	AVG(s.salary) salary, 
	YEAR(s.from_date) calender_year
from t_salaries s 
	join t_employees e ON e.emp_no = s.emp_no
	join t_dept_emp de ON de.emp_no = e.emp_no
	join t_departments d ON d.dept_no = de.dept_no
GROUP BY d.dept_no, e.gender, calender_year
Having calender_year <= 2002
ORDER BY d.dept_no; 


-- KBQ 3: average male and female salary per department within a certain salary range.
DROP procedure if exists avg_gender_department_salary;
DELIMITER $$
CREATE PROCEDURE avg_gender_department_salary(IN minimum_salary FLOAT, IN maximum_salary FLOAT)
BEGIN
	SELECT e.gender, 
		d.dept_name, 
		ROUND(AVG(s.salary), 2) salary
	from t_salaries s 
		join t_employees e ON e.emp_no = s.emp_no
		join t_dept_emp de ON de.emp_no = e.emp_no
		join t_departments d ON d.dept_no = de.dept_no
    	WHERE s.salary between minimum_salary AND maximum_salary
	GROUP BY d.dept_no, e.gender
    ORDER BY e.gender;
END $$
DELIMITER ;

-- for instance we exclude the salaries below 50k and over 90k because few employees were paid in that range and they are outliers
Call avg_gender_department_salary(50000, 90000);
