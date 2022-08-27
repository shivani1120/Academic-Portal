--DEAN ACADEMIC OFFICE
CREATE ROLE dao SUPERUSER LOGIN PASSWORD 'iitropar';
CREATE ROLE grp_role_students;
CREATE ROLE grp_role_faculty;

GRANT SELECT on terms to grp_role_students;
GRANT SELECT on batches to grp_role_students;
GRANT SELECT on courses to grp_role_students;
GRANT SELECT on students to grp_role_students;
GRANT SELECT on faculty to grp_role_students;
GRANT SELECT on faculty_advisor to grp_role_students;
GRANT SELECT on time_slots to grp_role_students;
GRANT SELECT on prerequisites to grp_role_students;
GRANT SELECT on course_offerings to grp_role_students;
GRANT SELECT on teaches to grp_role_students;

GRANT SELECT on terms to grp_role_faculty;
GRANT SELECT on batches to grp_role_faculty;
GRANT SELECT on courses to grp_role_faculty;
GRANT SELECT, REFERENCES on students to grp_role_faculty;
GRANT SELECT on faculty to grp_role_faculty;
GRANT SELECT on faculty_advisor to grp_role_faculty;
GRANT SELECT on time_slots to grp_role_faculty;
GRANT SELECT on prerequisites to grp_role_faculty;
GRANT SELECT, INSERT on course_offerings to grp_role_faculty;
GRANT SELECT, INSERT on teaches to grp_role_faculty;

CREATE TABLE IF NOT EXISTS terms (
  term_id INT GENERATED ALWAYS AS IDENTITY,
  semester INT NOT NULL,
  year INT NOT NULL,
  PRIMARY KEY(term_id)
);

--tested
CREATE TABLE IF NOT EXISTS batches (
  batch_id VARCHAR(50) NOT NULL,
  department VARCHAR (50) NOT NULL,
  degree VARCHAR (50) NOT NULL,
  join_year INT NOT NULL,
  graduate_year INT NOT NULL,
  PRIMARY KEY(batch_id)
);

--tested
CREATE TABLE IF NOT EXISTS courses (
  course_id VARCHAR (50) UNIQUE NOT NULL PRIMARY KEY,
  title VARCHAR (50) NOT NULL,
  department VARCHAR (50) NOT NULL,
  lectures numeric(5, 2) NOT NULL,
  tutorials numeric(5, 2) NOT NULL,
  practical numeric(5, 2) NOT NULL,
  self_study numeric(5, 2) NOT NULL,
  credits numeric(5, 2) NOT NULL
);

--tested
CREATE TABLE IF NOT EXISTS students (
  student_id VARCHAR (50) UNIQUE NOT NULL PRIMARY KEY,
  name VARCHAR (50) NOT NULL,
  batch_id VARCHAR(50) NOT NULL,
  FOREIGN KEY(batch_id) references batches(batch_id)
);

--tested
CREATE TABLE IF NOT EXISTS faculty (
  faculty_id VARCHAR (50) UNIQUE NOT NULL PRIMARY KEY,
  name VARCHAR (50) NOT NULL,
  department VARCHAR (50) NOT NULL
);

--tested
CREATE TABLE IF NOT EXISTS faculty_advisor (
  faculty_id VARCHAR (50) NOT NULL,
  batch_id VARCHAR(50) NOT NULL,
  PRIMARY KEY (faculty_id, batch_id),
  FOREIGN KEY(faculty_id) references faculty(faculty_id),
  FOREIGN KEY(batch_id) references batches(batch_id)
);

--tested
CREATE TABLE IF NOT EXISTS time_slots (
  term_id INT NOT NULL,
  slot_id VARCHAR(50) NOT NULL,
  course_id VARCHAR(50) NOT NULL,
  PRIMARY KEY(term_id, slot_id, course_id),
  FOREIGN KEY(term_id) references terms(term_id),
  FOREIGN KEY(course_id) references courses(course_id)
);

--tested
CREATE TABLE IF NOT EXISTS prerequisites (
  course_id VARCHAR(50) NOT NULL,
  prerequisite_id VARCHAR(50) NOT NULL,
  PRIMARY KEY(course_id, prerequisite_id),
  FOREIGN KEY(course_id) references courses(course_id),
  FOREIGN KEY(prerequisite_id) references courses(course_id)
);

--tested
CREATE TABLE IF NOT EXISTS dao_tickets(
  course_offering_id INT NOT NULL,
  faculty_id VARCHAR(50) NOT NULL,
  student_id VARCHAR(50) NOT NULL,
  faculty_status INT NOT NULL,
  status INT NOT NULL,
  PRIMARY KEY(faculty_id, course_offering_id, student_id),
  FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id),
  FOREIGN KEY(faculty_id) references faculty(faculty_id),
  FOREIGN KEY(student_id) references students(student_id)
);

--tested
CREATE OR REPLACE FUNCTION insert_course_in_time_slot(IN slot_identifier VARCHAR(50), IN course_identifier VARCHAR(50), IN semester_identifier INT, IN year_identifier INT)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  term_identifier INT;
BEGIN
    SELECT terms.term_id 
    INTO term_identifier 
    FROM terms 
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    EXECUTE format(
      'INSERT INTO %I
      VALUES
      (%s, %L, %L)', 'time_slots', term_identifier, slot_identifier, course_identifier);
      
    RETURN 'Course inserted in Time-Slot successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION generate_transcript(IN student_identifier VARCHAR(50), IN semester_identifier INT, IN year_identifier INT)
  RETURNS TABLE (
		course_id VARCHAR(50),
		grade VARCHAR(50)
	)
  LANGUAGE plpgsql AS
$$
DECLARE
  term_identifier INT;
BEGIN
    SELECT terms.term_id 
    INTO term_identifier 
    FROM terms 
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    RETURN QUERY
    EXECUTE format('
      SELECT co.course_id, st.grade
      FROM %I AS st, course_offerings co
      WHERE st.course_offering_id = co.course_offering_id and co.term_id = %s', 'transcript_' || student_identifier, term_identifier);
    
END
$$;

--tested
CREATE OR REPLACE FUNCTION grade_copy(IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  term_identifier INT;
  course_offering_identifier  INT;
  f record;
  results_course_offering_table VARCHAR(50);
BEGIN
    SELECT terms.term_id 
    INTO term_identifier 
    FROM terms 
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    SELECT course_offerings.course_offering_id 
    INTO course_offering_identifier 
    FROM course_offerings 
    where course_offerings.course_id = course_identifier and course_offerings.term_id = term_identifier and course_offerings.section_id = section_identifier;
    
    results_course_offering_table := 'results_' || course_offering_identifier;

    for f in EXECUTE format('select * from %I', results_course_offering_table)
      loop 
        EXECUTE format(
          'INSERT INTO %I
          VALUES
          (%L, %L)', 'transcript_' || f.student_id, course_offering_identifier, f.grade);
  	end loop;
    
  RETURN 'Grades copied successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION get_tickets_dao()
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  cur_fa_identifier record;
BEGIN
    CREATE TEMP TABLE tmp_all_tickets 
    (course_offering_identifier INT, 
    faculty_id VARCHAR(50),
    student_identifier VARCHAR(50),
    faculty_status INT,
    status INT);

    FOR cur_fa_identifier in (SELECT * from faculty_advisor)
    loop
      EXECUTE format('
        INSERT INTO tmp_all_tickets
        SELECT course_offering_id, %L, student_id, status, %s
        FROM %I
        WHERE status != 0', cur_fa_identifier.faculty_id, 0, 'tickets_' || cur_fa_identifier.faculty_id);
    end loop;

    INSERT INTO dao_tickets
    (SELECT * from tmp_all_tickets
    except
    SELECT * from dao_tickets);

    DROP TABLE tmp_all_tickets;
    
    RETURN 'Tickets added successfully!';
END
$$;

-- tested
CREATE OR REPLACE FUNCTION update_status_in_dao_tickets(IN student_identifier VARCHAR(50), IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT, IN faculty_identifier VARCHAR(50), IN result BOOLEAN)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  course_offering_identifier INT;
  term_identifier INT;
  result_int INT;
BEGIN
    SELECT terms.term_id 
    INTO term_identifier 
    FROM terms 
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    SELECT course_offerings.course_offering_id 
    INTO course_offering_identifier 
    FROM course_offerings 
    where course_offerings.course_id = course_identifier and course_offerings.term_id = term_identifier and course_offerings.section_id = section_identifier;
    
    if result = TRUE
      then
        result_int := 1;
    else 
      result_int := 2;
    end if;

    EXECUTE format(
      'UPDATE dao_tickets
      SET status = %s
      WHERE course_offering_id = %L
      and faculty_id = %L
      and student_id = %L', result_int, course_offering_identifier, faculty_identifier, student_identifier);
      
    RETURN 'Status updated successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION update_status_in_student_tickets()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format(
      'INSERT INTO %I
      (course_offering_id, status)
      VALUES
      (%L, %s)', 'viewtickets_' || NEW.student_id, NEW.course_offering_id, NEW.status);

      RETURN NEW;
END
$$;

--tested
CREATE TRIGGER trig_update_in_dao_tickets
AFTER UPDATE
ON dao_tickets
FOR EACH ROW
EXECUTE PROCEDURE update_status_in_student_tickets();

--tested
CREATE OR REPLACE FUNCTION create_fa_role_per_batch()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
BEGIN
  EXECUTE format('
    CREATE ROLE %I LOGIN PASSWORD %L', 'fa_' || NEW.batch_id, 'iitropar');
  RETURN NEW;
END
$$;

--tested
CREATE TRIGGER trig_insert_batches
AFTER INSERT
ON batches
FOR EACH ROW
EXECUTE PROCEDURE create_fa_role_per_batch();

--tested
CREATE OR REPLACE FUNCTION view_dao_tickets()
  RETURNS TABLE (
    student_id VARCHAR(50),
		course_id VARCHAR(50),
    section_id INT,
    semester INT,
    year INT,
    faculty_id VARCHAR(50),
    faculty_status VARCHAR(50),
    status VARCHAR(50)
	)
  LANGUAGE plpgsql AS
$$
DECLARE
  f record;  
  faculty_status_in_text VARCHAR(50);
  status_in_text VARCHAR(50);
BEGIN
    CREATE TEMP TABLE tickets_to_display(
      student_id VARCHAR(50),
      course_id VARCHAR(50),
      section_id INT,
      semester INT,
      year INT,
      faculty_id VARCHAR(50),
      faculty_status VARCHAR(50),
      status VARCHAR(50)
    );
    
    FOR f in (SELECT * from dao_tickets, course_offerings co, terms WHERE dao_tickets.course_offering_id = co.course_offering_id AND terms.term_id = co.term_id)
    loop
      IF (f.faculty_status = 1)
        THEN
          faculty_status_in_text := 'Ticket Accepted by Faculty Advisor';
      ELSIF (f.faculty_status = 2)
        THEN
          faculty_status_in_text := 'Ticket Rejected by Faculty Advisor';
      ELSIF (f.faculty_status = 3)
        THEN
          faculty_status_in_text := 'Ticket Forwarded by Faculty Advisor';
      END IF;

      IF(f.status = 0)
        THEN 
          status_in_text := 'Ticket Not Reviewed Yet';
      ELSIF (f.status = 1)
        THEN
          status_in_text := 'Ticket Accepted';
      ELSIF (f.status = 2)
        THEN
          status_in_text := 'Ticket Rejected';
      END IF;

      EXECUTE format('
        INSERT INTO tickets_to_display
        VALUES(%L, %L, %s, %s, %s, %L, %L, %L)', 
        f.student_id, f.course_id, f.section_id, f.semester, f.year, f.faculty_id, faculty_status_in_text, status_in_text);
    end loop;

    RETURN QUERY SELECT * from tickets_to_display;  
    DROP TABLE tickets_to_display;
    RETURN;    
END
$$;