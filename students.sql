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
          
        average_credits := 1.25 * ((last_term_credits + second_last_term_credits) / 2);

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