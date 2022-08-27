--FACULTIES
--tested
CREATE TABLE IF NOT EXISTS course_offerings (
  course_offering_id INT GENERATED ALWAYS AS IDENTITY,
  course_id VARCHAR (50) NOT NULL,
  term_id INT NOT NULL,
  section_id INT NOT NULL,
  slot_id VARCHAR (50) NOT NULL,
  batch_ids VARCHAR(50) ARRAY NOT NULL,
  cgpa_cutoff NUMERIC(4, 2) NOT NULL,
  PRIMARY KEY(course_offering_id),
  FOREIGN KEY(term_id, slot_id, course_id) references time_slots(term_id, slot_id, course_id)
);

--tested
CREATE TABLE IF NOT EXISTS teaches (
  faculty_id VARCHAR (50) NOT NULL,
  course_offering_id INT NOT NULL,
  PRIMARY KEY(faculty_id, course_offering_id),
  FOREIGN KEY(faculty_id) references faculty(faculty_id),
  FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id)
);

--tested
CREATE OR REPLACE FUNCTION create_per_course_offering_table()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        student_id VARCHAR (50) NOT NULL PRIMARY KEY,
        FOREIGN KEY(student_id) references students(student_id)
      )', 'registrations_' || NEW.course_offering_id);

    EXECUTE format('
      GRANT SELECT, INSERT on %I to grp_role_students', 'registrations_' || NEW.course_offering_id);

    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        student_id VARCHAR (50) NOT NULL PRIMARY KEY,
        grade VARCHAR (50) NOT NULL,
        FOREIGN KEY(student_id) references students(student_id)
      )', 'results_' || NEW.course_offering_id);

    EXECUTE format('
      GRANT SELECT, INSERT on %I to %I', 'registrations_' || NEW.course_offering_id, current_user);
    
    EXECUTE format('
      GRANT SELECT, INSERT on %I to %I', 'results_' || NEW.course_offering_id, current_user);

    EXECUTE format('
      INSERT INTO teaches VALUES(%L, %L)', current_user, NEW.course_offering_id);

    RETURN NEW;
END
$$;

--tested
CREATE TRIGGER trig_insert_in_course_offerings
AFTER INSERT
ON course_offerings
FOR EACH ROW
EXECUTE PROCEDURE create_per_course_offering_table();

--tested
CREATE OR REPLACE FUNCTION upload_grade_in_course_offering_table(IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT, IN file_path VARCHAR(500))
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  course_offering_identifier INT;
  term_identifier INT;
BEGIN
    SELECT terms.term_id 
    INTO term_identifier 
    FROM terms 
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    SELECT course_offerings.course_offering_id 
    INTO course_offering_identifier 
    FROM course_offerings 
    where course_offerings.course_id = course_identifier and course_offerings.term_id = term_identifier and course_offerings.section_id = section_identifier;
    
    EXECUTE format(
      'COPY %I
      FROM %L
      DELIMITER '',''
      CSV HEADER', 'results_' || course_offering_identifier, file_path);

    RETURN 'Grades uploaded successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION course_offering_by_faculty(IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT, IN slot_identifier VARCHAR(50), IN batch_ids_allowed VARCHAR(50) ARRAY, IN cgpa_cutoff_value NUMERIC(4, 2) DEFAULT 00.00)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  term_identifier INT;
  length INT;
  batch_identifier VARCHAR(50);
BEGIN
    SELECT terms.term_id
    INTO term_identifier
    FROM terms
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    EXECUTE format(
      'INSERT INTO course_offerings(course_id, term_id, section_id, slot_id, batch_ids, cgpa_cutoff)
      VALUES
      (%L, %s, %s, %L, %L, %L)', course_identifier, term_identifier, section_identifier, slot_identifier, batch_ids_allowed, cgpa_cutoff_value);

    RETURN 'Course offered successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION show_course_offering_registrations(IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT)
  RETURNS TABLE (
		student_id VARCHAR(50)
	)
  LANGUAGE plpgsql AS
$$
DECLARE
  course_offering_identifier INT;
  term_identifier INT;
BEGIN
    SELECT terms.term_id
    INTO term_identifier
    FROM terms
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;

    SELECT course_offerings.course_offering_id 
    INTO course_offering_identifier 
    FROM course_offerings 
    where course_offerings.course_id = course_identifier and course_offerings.term_id = term_identifier and course_offerings.section_id = section_identifier;
    
    RETURN QUERY
      EXECUTE format('
      SELECT *
      FROM %I', 'registrations_' || course_offering_identifier);
END
$$;

--tested
CREATE OR REPLACE FUNCTION create_per_faculty_role()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
BEGIN
  EXECUTE format('
    CREATE ROLE %I LOGIN PASSWORD %L', NEW.faculty_id, 'iitropar');

  EXECUTE format('GRANT grp_role_faculty to %I', NEW.faculty_id);
  EXECUTE format('GRANT pg_read_server_files to %I', NEW.faculty_id);

  RETURN NEW;
END
$$;

--tested
CREATE TRIGGER trig_insert_faculty
AFTER INSERT
ON faculty
FOR EACH ROW
EXECUTE PROCEDURE create_per_faculty_role();