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