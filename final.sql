CREATE ROLE dao SUPERUSER LOGIN PASSWORD 'iitropar';
CREATE ROLE grp_role_students;
CREATE ROLE grp_role_faculty;

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
CREATE TABLE IF NOT EXISTS dao_tickets (
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


--FACULTY ADVISORS
--tested
CREATE OR REPLACE FUNCTION create_per_fa_tables()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        course_offering_id INT NOT NULL,
        student_id VARCHAR(50) NOT NULL,
        status INT NOT NULL,
        PRIMARY KEY(student_id, course_offering_id),
        FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id),
        FOREIGN KEY(student_id) references students(student_id)
      )', 'tickets_' || NEW.faculty_id);

    EXECUTE format('
      GRANT SELECT, INSERT, UPDATE on %I to %I', 'tickets_' || NEW.faculty_id, NEW.faculty_id);

    EXECUTE format('GRANT %I to %I', 'fa_' || NEW.batch_id, NEW.faculty_id);

    RETURN NEW;
END
$$;

--tested
CREATE TRIGGER trig_insert_in_fa
AFTER INSERT
ON faculty_advisor
FOR EACH ROW
EXECUTE PROCEDURE create_per_fa_tables();

--tested
CREATE OR REPLACE FUNCTION get_tickets_fa()
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  cur_student_identifier record;
BEGIN
    CREATE TEMP TABLE tmp_all_tickets 
    (course_offering_identifier INT, 
    student_identifier VARCHAR(50),
    status INT);

    CREATE TEMP TABLE req_batch_ids(batch_identifier VARCHAR(50));

    CREATE TEMP TABLE cur_students(student_identifier VARCHAR(50));

    EXECUTE format('
      INSERT INTO req_batch_ids
      SELECT fa.batch_id
      FROM faculty_advisor fa
      WHERE fa.faculty_id = %L;
      ', current_user);

    EXECUTE format('
      INSERT INTO cur_students
      select st.student_id
      from students st
      where st.batch_id in (SELECT * from req_batch_ids)');

    FOR cur_student_identifier in (SELECT * from cur_students)
    loop
      EXECUTE format('
        INSERT INTO tmp_all_tickets
        SELECT course_offering_id, %L, %s
        FROM %I', cur_student_identifier.student_identifier, 0, 'tickets_' || cur_student_identifier.student_identifier);
    end loop;

    EXECUTE format('INSERT INTO %I
      (SELECT * from tmp_all_tickets 
      except
      SELECT * from %I)
      ', 'tickets_' || current_user, 'tickets_' || current_user);

    DROP TABLE tmp_all_tickets;
    DROP TABLE req_batch_ids;
    DROP TABLE cur_students;
    
    RETURN 'Tickets added successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION update_status_in_fa_tickets(IN student_identifier VARCHAR(50), IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT, IN result INT)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  course_offering_identifier INT;
  term_identifier INT;
BEGIN
    IF (result > 3 or result < 1)
    THEN 
      raise EXCEPTION 'Invalid Result. Please enter: \n1) For accepting the ticket \n2) For rejecting the ticket \n3) For forwarding the ticket';
    END IF;
    
    SELECT terms.term_id
    INTO term_identifier 
    FROM terms 
    WHERE terms.year = year_identifier and terms.semester = semester_identifier;
    
    SELECT course_offerings.course_offering_id 
    INTO course_offering_identifier 
    FROM course_offerings 
    where course_offerings.course_id = course_identifier and course_offerings.term_id = term_identifier and course_offerings.section_id = section_identifier;

    raise info '%, %', result, course_offering_identifier;

    EXECUTE format(
      'UPDATE %I
      SET status = %s
      WHERE course_offering_id = %s
      and student_id = %L', 'tickets_' || current_user, result, course_offering_identifier, student_identifier);
      
    RETURN 'Status updated successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION view_fa_tickets(IN faculty_identifier VARCHAR(50))
  RETURNS TABLE (
    student_id VARCHAR(50),
		course_id VARCHAR(50),
    section_id INT,
    semester INT,
    year INT,
    status VARCHAR(50)
	)
  LANGUAGE plpgsql AS
$$
DECLARE
  f record;  
  status_in_text VARCHAR(50);
BEGIN
    CREATE TEMP TABLE tickets_to_display(
      student_id VARCHAR(50),
      course_id VARCHAR(50),
      section_id INT,
      semester INT,
      year INT,
      status VARCHAR(50)
    );
    
    FOR f in EXECUTE format('SELECT * from %I, course_offerings co, terms WHERE %I.course_offering_id = co.course_offering_id
    AND co.term_id = terms.term_id', 'tickets_' || faculty_identifier, 'tickets_' || faculty_identifier)
    loop
      IF(f.status = 0)
        THEN 
          status_in_text := 'Ticket Not Reviewed Yet';
      ELSIF (f.status = 1)
        THEN
          status_in_text := 'Ticket Accepted';
      ELSIF (f.status = 2)
        THEN
          status_in_text := 'Ticket Rejected';
      ELSIF (f.status = 3)
        THEN
          status_in_text := 'Ticket Forwarded';
      END IF;

      EXECUTE format('
        INSERT INTO tickets_to_display
        VALUES(%L, %L, %s, %s, %s, %L)', 
        f.student_id, f.course_id, f.section_id, f.semester, f.year, status_in_text);
    end loop;

    RETURN QUERY SELECT * from tickets_to_display;    
    DROP TABLE tickets_to_display;
    RETURN;  
END
$$;

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

--STUDENTS
--tested
CREATE OR REPLACE FUNCTION create_per_student_tables()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format('
    CREATE ROLE %I LOGIN PASSWORD %L', NEW.student_id, 'iitropar');    
    
    EXECUTE format('GRANT grp_role_students to %I', NEW.student_id);
    
    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        course_offering_id INT NOT NULL PRIMARY KEY,
        grade VARCHAR (50) NOT NULL,
        FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id)
      )', 'transcript_' || NEW.student_id);

    EXECUTE format('
      GRANT SELECT on %I to %I', 'transcript_' || NEW.student_id, NEW.student_id);

    EXECUTE format('
      GRANT SELECT on %I to grp_role_faculty', 'transcript_' || NEW.student_id);
      
    EXECUTE format('
      GRANT SELECT on %I to %I', 'transcript_' || NEW.student_id, 'fa_' || NEW.batch_id);

    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        course_offering_id INT NOT NULL PRIMARY KEY,
        FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id)
      )', 'registrations_' || NEW.student_id);

    EXECUTE format('
      GRANT SELECT, INSERT on %I to %I', 'registrations_' || NEW.student_id, NEW.student_id);

    EXECUTE format('
      GRANT SELECT on %I to %I', 'registrations_' || NEW.student_id, 'fa_' || NEW.batch_id);

    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        course_offering_id INT NOT NULL PRIMARY KEY,
        FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id)
      )', 'tickets_' || NEW.student_id);

    EXECUTE format('
      GRANT SELECT, INSERT on %I to %I', 'tickets_' || NEW.student_id, NEW.student_id);

    EXECUTE format('
      GRANT SELECT on %I to %I', 'tickets_' || NEW.student_id, 'fa_' || NEW.batch_id);

    EXECUTE format('
      CREATE TABLE IF NOT EXISTS %I (
        course_offering_id INT NOT NULL PRIMARY KEY,
        status INT NOT NULL,
        FOREIGN KEY(course_offering_id) references course_offerings(course_offering_id)
      )', 'viewtickets_' || NEW.student_id);

    EXECUTE format('
      GRANT SELECT on %I to %I', 'viewtickets_' || NEW.student_id, NEW.student_id);

    EXECUTE format('
      GRANT SELECT on %I to %I', 'viewtickets_' || NEW.student_id, 'fa_' || NEW.batch_id);
    
    EXECUTE format('
      DROP TRIGGER 
      IF EXISTS trig_after_insert_in_student_registration_table
      ON %I',
      'registrations_' || NEW.student_id);
    
    EXECUTE format('
      CREATE TRIGGER trig_after_insert_in_student_registration_table
      AFTER INSERT
      ON %I
      FOR EACH ROW
      EXECUTE PROCEDURE add_entry_in_course_registration_table()', 
      'registrations_' || NEW.student_id);
      
    EXECUTE format('
      DROP TRIGGER
      IF EXISTS trig_before_insert_in_student_registration_table
      ON %I',
      'registrations_' || NEW.student_id);

    EXECUTE format('
      CREATE TRIGGER trig_before_insert_in_student_registration_table
      BEFORE INSERT
      ON %I
      FOR EACH ROW
      EXECUTE PROCEDURE verify_constraints_before_registration()', 
      'registrations_' || NEW.student_id);
    
    RETURN NEW;
END
$$;

--tested
CREATE TRIGGER trig_insert_in_students
AFTER INSERT
ON students
FOR EACH ROW
EXECUTE PROCEDURE create_per_student_tables();

--tested
CREATE OR REPLACE FUNCTION add_entry_in_course_registration_table()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
DECLARE
  student_table_name VARCHAR(50);
  first_idx INT;
  student_identifier VARCHAR(50);
BEGIN
    student_table_name := TG_TABLE_NAME;
    first_idx := position('_' in student_table_name);
    student_identifier := substring(student_table_name from first_idx + 1 for length(student_table_name) - first_idx);
    
    EXECUTE format(
      'INSERT INTO %I
      (student_id)
      VALUES
      (%L)', 'registrations_' || NEW.course_offering_id, student_identifier);
      
    RETURN NEW;
END
$$;

--tested
CREATE OR REPLACE FUNCTION student_course_registration(IN course_identifier VARCHAR(50), IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT)
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
      'INSERT INTO %I
      (course_offering_id)
      VALUES
      (%L)', 'registrations_' || current_user, course_offering_identifier);

    RETURN 'Course registration completed successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION get_student_cgpa(IN student_identifier VARCHAR(50))
  RETURNS NUMERIC(4, 2)
  LANGUAGE plpgsql AS
$$
DECLARE
  total_credits NUMERIC(6, 2);
  total_points NUMERIC(8, 2);
  cgpa NUMERIC(4, 2);
  f record;

BEGIN
  total_credits = 0.0;
  total_points = 0.0;
  for f in 
    EXECUTE format('
      select %I.grade as grade, courses.credits as credits
      from %I, course_offerings, courses
      where %I.course_offering_id = course_offerings.course_offering_id and course_offerings.course_id = courses.course_id', 'transcript_' || student_identifier, 'transcript_' || student_identifier, 'transcript_' || student_identifier)
  loop 
	  if f.grade = 'A'
      then
          total_credits := total_credits + f.credits;
          total_points := total_points + f.credits * 10;
    elsif f.grade = 'A-'
      then
          total_credits := total_credits + f.credits;
          total_points := total_points + f.credits * 9;
    elsif f.grade = 'B'
      then
          total_credits := total_credits + f.credits;
          total_points := total_points + f.credits * 8;
    elsif f.grade = 'B-'
      then
          total_credits := total_credits + f.credits;
          total_points := total_points + f.credits * 7;
    elsif f.grade = 'C'
      then
        total_credits := total_credits + f.credits;
        total_points := total_points + f.credits * 6;
    elsif f.grade = 'C-'
      then
        total_credits := total_credits + f.credits;
        total_points := total_points + f.credits * 5;
    elsif f.grade = 'D'
      then
        total_credits := total_credits + f.credits;
        total_points := total_points + f.credits * 4;
    end if;
  end loop; 
  
  if(total_credits != 0)
    then
      cgpa := total_points / total_credits;
  else
    cgpa := 0.0;
  end if;

  RETURN cgpa;
END
$$;

--tested
CREATE OR REPLACE FUNCTION verify_constraints_before_registration()
  RETURNS TRIGGER
  LANGUAGE plpgsql AS
$$
DECLARE
  student_table_name VARCHAR(50);
  first_idx INT;
  student_identifier VARCHAR(50);

  ticket_status INT;

  course_offering_identifier INT;
  course_identifier VARCHAR(50);
  term_identifier INT;
  section_identifier INT;
  slot_identifier VARCHAR(50);
  cgpa_cutoff_value NUMERIC(4, 2);
  batch_identifiers_allowed VARCHAR(50) ARRAY;

  student_cgpa NUMERIC(4, 2);
  student_batch_identifier VARCHAR(50);

  second_last_term_semester INT;
  second_last_term_year INT;
  last_term_semester INT;
  last_term_year INT;

  cur_term_semester INT;
  cur_term_year INT;
  
  second_last_term_credits numeric(5, 2);
  last_term_credits numeric(5, 2);
  average_credits numeric(5, 2);
  credits_cut_off numeric(5, 2);
  current_registered_credits numeric(5, 2);

  completed_course_data record;
  course_data record;
  new_course_credit numeric(5, 2);

BEGIN
    student_table_name := TG_TABLE_NAME;
    first_idx := position('_' in student_table_name);
    student_identifier := substring(student_table_name from first_idx + 1 for length(student_table_name) - first_idx);


    SELECT course_id, term_id, section_id, slot_id, batch_ids, cgpa_cutoff
    INTO course_identifier, term_identifier, section_identifier, slot_identifier, batch_identifiers_allowed, cgpa_cutoff_value
    FROM course_offerings
    WHERE course_offerings.course_offering_id = NEW.course_offering_id;
    
    SELECT semester, year
    INTO cur_term_semester, cur_term_year
    FROM terms
    WHERE terms.term_id = term_identifier;

    student_cgpa := get_student_cgpa(student_identifier);
    
    SELECT batch_id
    INTO student_batch_identifier
    FROM students
    WHERE students.student_id = student_identifier;

    CREATE TEMP TABLE registered_courses(course_id VARCHAR(50));

    EXECUTE format('
      INSERT INTO registered_courses
      SELECT course_id
      FROM %I, course_offerings co
      WHERE %I.course_offering_id = co.course_offering_id
      AND grade != ''E'' AND grade != ''F''', 'transcript_' || student_identifier, 'transcript_' || student_identifier);

    EXECUTE format('
      INSERT INTO registered_courses
      SELECT course_id
      FROM
      (
        (SELECT course_offering_id
        FROM %I)
        EXCEPT
        (SELECT course_offering_id
        FROM %I)
      ) AS rc, course_offerings co
      WHERE rc.course_offering_id = co.course_offering_id', 'registrations_' || student_identifier, 'transcript_' || student_identifier);
    
    IF EXISTS(SELECT * from registered_courses rc WHERE rc.course_id = course_identifier) 
        THEN raise EXCEPTION 'Registration Unsuccessful! Course already completed/registered.';
    END IF;

    DROP TABLE registered_courses;

    EXECUTE format(
    'SELECT status
    FROM %I
    WHERE course_offering_id = %L', 'viewtickets_' || student_identifier, NEW.course_offering_id)
    INTO 
    ticket_status;

    IF(ticket_status IS NULL)
    THEN
      ticket_status := 0;
    END IF;

    IF(ticket_status != 1)
      THEN
        IF(student_cgpa < cgpa_cutoff_value)
          THEN
            raise EXCEPTION 'Registration Unsuccessful! Your CGPA is lower than the cutoff(%).', cgpa_cutoff_value;
        END IF;

        IF(student_batch_identifier != ALL(batch_identifiers_allowed))
          THEN
            raise EXCEPTION 'Registration Unsuccessful! Course is not offered for your batch(%).', student_batch_identifier;
        END IF;

        CREATE TEMP TABLE course_prereq(course_id VARCHAR(50));
        CREATE TEMP TABLE completed_courses(course_id VARCHAR(50));
        
        EXECUTE format('
          INSERT INTO course_prereq
          SELECT prerequisite_id
          FROM prerequisites
          WHERE course_id = %L', course_identifier);

        EXECUTE format('
          INSERT INTO completed_courses
          SELECT course_id
          FROM %I, course_offerings co
          WHERE %I.course_offering_id = co.course_offering_id
          AND grade != ''E'' AND grade != ''F''', 'transcript_' || student_identifier, 'transcript_' || student_identifier);
        
        IF EXISTS (((SELECT * FROM course_prereq) except (SELECT * from completed_courses)) LIMIT 1) 
            THEN raise EXCEPTION 'Registration Unsuccessful! Prequisite courses not completed.';
        END IF;

        DROP TABLE course_prereq;
        DROP TABLE completed_courses;

        CREATE TEMP TABLE cur_slot_table(slot_id VARCHAR(50));
        CREATE TEMP TABLE registered_slots(slot_id VARCHAR(50));

        EXECUTE format('INSERT into cur_slot_table VALUES(%L)', slot_identifier);

        EXECUTE format('
          INSERT INTO registered_slots
          SELECT distinct slot_id
          FROM %I, course_offerings co
          WHERE %I.course_offering_id = co.course_offering_id
          and co.term_id = %L', 'registrations_' || student_identifier, 'registrations_' || student_identifier, term_identifier);

        IF NOT EXISTS ((SELECT * FROM cur_slot_table) except (SELECT * from registered_slots))
            THEN raise EXCEPTION 'Registration Unsuccessful! A same-slot course registration already exists.';
        END IF;

        DROP TABLE registered_slots;
        DROP TABLE cur_slot_table;

        -- Assumption that there are two semesters in a year
        IF cur_term_semester = 1
          THEN 
            second_last_term_semester := 1;
            second_last_term_year := cur_term_year - 1;
            last_term_semester := 2;
            last_term_year := cur_term_year - 1;
        ELSE
            second_last_term_semester := 2;
            second_last_term_year := cur_term_year - 1;
            last_term_semester := 1;
            last_term_year := cur_term_year;  
        END IF;

        second_last_term_credits := 0.0;
        last_term_credits := 0.0;

        IF NOT EXISTS (SELECT * from terms WHERE terms.year = last_term_year AND terms.semester = last_term_semester)
          THEN
            last_term_credits := 19.5;
        ELSE
          FOR completed_course_data in 
            EXECUTE format('
            SELECT * 
            FROM %I, courses, course_offerings co, terms
            WHERE co.course_offering_id = %I.course_offering_id 
            AND co.course_id = courses.course_id
            AND co.term_id = terms.term_id
            AND terms.semester = %L 
            AND terms.year = %L', 'transcript_' || student_identifier, 'transcript_' || student_identifier, last_term_semester, last_term_year)
          LOOP
            IF completed_course_data.grade = 'A' OR completed_course_data.grade = 'A-' OR completed_course_data.grade = 'B'
            OR completed_course_data.grade = 'B-' OR completed_course_data.grade = 'C' OR completed_course_data.grade = 'C-'
            OR completed_course_data.grade = 'D'
              THEN
                last_term_credits := last_term_credits + completed_course_data.credits;
            END IF;
          END LOOP;
        END IF;

        IF NOT EXISTS (SELECT * from terms WHERE terms.year = second_last_term_year AND terms.semester = second_last_term_semester)
          THEN
            second_last_term_credits := 19.5;
        ELSE
          FOR completed_course_data in 
            EXECUTE format('
            SELECT * 
            FROM %I, courses, course_offerings co, terms
            WHERE co.course_offering_id = %I.course_offering_id 
            AND co.course_id = courses.course_id
            AND co.term_id = terms.term_id
            AND terms.semester = %L 
            AND terms.year = %L', 'transcript_' || student_identifier, 'transcript_' || student_identifier, second_last_term_semester, second_last_term_year)
          LOOP
            IF completed_course_data.grade = 'A' OR completed_course_data.grade = 'A-' OR completed_course_data.grade = 'B'
            OR completed_course_data.grade = 'B-' OR completed_course_data.grade = 'C' OR completed_course_data.grade = 'C-'
            OR completed_course_data.grade = 'D'
              THEN
                second_last_term_credits := second_last_term_credits + completed_course_data.credits;
            END IF;
          END LOOP;
        END IF;
          
        average_credits := (last_term_credits + second_last_term_credits) / 2;

        IF average_credits > 19.5
          THEN
            credits_cut_off := 19.5;
        ELSE 
          credits_cut_off := average_credits;
        END IF;
        
        current_registered_credits := 0;

        FOR course_data in 
            EXECUTE format('
            SELECT * 
            FROM %I, courses, course_offerings co, terms
            WHERE co.course_offering_id = %I.course_offering_id 
            AND co.course_id = courses.course_id
            AND co.term_id = terms.term_id
            AND terms.semester = %L 
            AND terms.year = %L', 'registrations_' || student_identifier, 'registrations_' || student_identifier, cur_term_semester, cur_term_year)
        LOOP
            current_registered_credits := current_registered_credits + course_data.credits;
        END LOOP;

        SELECT courses.credits
        INTO new_course_credit
        FROM courses
        WHERE courses.course_id = course_identifier;

        IF current_registered_credits + new_course_credit > credits_cut_off
          THEN raise EXCEPTION 'Registration Unsuccessful! Credit limit exceeded. Your current registered credits are %. The permissible credit limit is %.', current_registered_credits, credits_cut_off;
        END IF;
    END IF;
    
    RETURN NEW;
END
$$;


--tested
CREATE OR REPLACE FUNCTION generate_student_ticket(IN course_identifier VARCHAR(50),  IN section_identifier INT, IN semester_identifier INT, IN year_identifier INT)
  RETURNS TEXT
  LANGUAGE plpgsql AS
$$
DECLARE
  term_identifier INT;
  course_offering_identifier VARCHAR(50);
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
      'INSERT INTO %I
      VALUES
      (%L)', 'tickets_' || current_user, course_offering_identifier);

    RETURN 'Ticket added successfully!';
END
$$;

--tested
CREATE OR REPLACE FUNCTION view_student_tickets(IN student_identifier VARCHAR(50))
  RETURNS TABLE (
		course_id VARCHAR(50),
    section_id INT,
    semester INT,
    year INT,
    status VARCHAR(50)
	)
  LANGUAGE plpgsql AS
$$
DECLARE
  f record;  
  status_in_text VARCHAR(50);
BEGIN
    CREATE TEMP TABLE tickets_to_display(
      course_id VARCHAR(50),
      section_id INT,
      semester INT,
      year INT,
      status VARCHAR(50)
    );
    
    FOR f in EXECUTE format('SELECT * from %I, course_offerings co, terms WHERE %I.course_offering_id = co.course_offering_id
    AND terms.term_id = co.term_id', 'viewtickets_' || student_identifier, 'viewtickets_' || student_identifier)
    loop
      IF (f.status = 1)
      THEN
        status_in_text := 'Ticket Accepted';
      ELSE
        status_in_text := 'Ticket Rejected';
      END IF;

      EXECUTE format('
        INSERT INTO tickets_to_display
        VALUES(%L, %s, %s, %s, %L)', 
        f.course_id, f.section_id, f.semester, f.year, status_in_text);
    end loop;

    FOR f in 
        EXECUTE format('SELECT * 
              FROM ((SELECT course_offering_id FROM %I) EXCEPT (SELECT course_offering_id FROM %I)) AS diff(course_offering_id), course_offerings co, terms
              WHERE diff.course_offering_id = co.course_offering_id
              AND co.term_id = terms.term_id', 'tickets_' || student_identifier, 'viewtickets_' || student_identifier)
    loop
      EXECUTE format('
        INSERT INTO tickets_to_display
        VALUES(%L, %s, %s, %s, %L)', 
        f.course_id, f.section_id, f.semester, f.year, 'No status');
    end loop;

    RETURN QUERY SELECT * from tickets_to_display;   
    DROP TABLE tickets_to_display;
    RETURN;   
END
$$;

CREATE OR REPLACE FUNCTION show_student_registrations(IN student_identifier VARCHAR(50), IN semester_identifier INT, IN year_identifier INT)
  RETURNS TABLE (
		course_id VARCHAR(50)
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
      SELECT co.course_id
      FROM %I, course_offerings co
      WHERE %I.course_offering_id = co.course_offering_id
      and co.term_id = %s', 'registrations_' || student_identifier, 'registrations_' || student_identifier, term_identifier);
END
$$;