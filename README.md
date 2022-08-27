# Academic Portal: DBMS

In this project, we designed and implemented a multi-user database application for managing the academic portal of an academic institute. The academic eco-system consisted of the following stakeholders:

* Students
* Faculty
* Batch Advisor
* Dean Academics Office

**Key concepts for the academic system:**

1. `Course Catalogue`: This contains all the list of courses which can be offered in the academic institute. For each course, we
have information on its credit structure (L-T-P-S-C) and list of prerequisites (if any).

2. `Course Offerings`: Each semester, a faculty offers one or multiple courses. These courses should be present in the
course catalogue. With each course offering, the instructor provides a timetable slot (from a list already defined by
the academic office at the start of semesters), a list of batches which are allowed to register in the course. In
addition, instructors may also define additional constraints (e.g., CGPA > 7.0).

3. `Student Registration`: A student registers for one or more courses. However, the number of credits he/she is
allowed is governed by the scheme governed by the institute (1.25 times the average of the credits earned in the
previous two semesters. Additionally, a student is not allowed to register for more than one course in a single
timetable slot.

4. `Ticket Generation`: If a student wishes to enroll for courses which are beyond what is allowed by the credit-limit
and the course-offering-restrictions, then he/she raises a ticket. This ticket first goes to the instructor of the course,
followed by the academic advisor and finally the Dean Academics office. Each of them can either accept and
forward OR reject. Final decision is made only by the dean academic office. You should store the history of
decisions made by various people.

5. `Report Generation`: Staff in the Dean’s office need to generate transcripts of students.

6. `Grade entry by Course Instructors`: Grades are to be imported from a csv file.


**Various Checks, Constraints and Privileges implemented:**

1. A student is not allowed to register for courses which are scheduled in the same time-slot.

2. A student is not allowed to register for a course without clearing the pre-req. Also he/she not allowed to register
for more than the allowed credit limit (unless his tickets are approved).

3. The course catalogue can be edited only by the Dean Academics office.

4. A student can see only his/her grades. But a faculty or Dean Academics office can see all the grades.


**Key Stored Procedures developed:**

1. Stored procedures for uploading the time-table slots for a semester (by academic staff), offering a course
(by faculty), registering a course (by student), ticket generation and propagation, generating the transcript (for a
given studentid) and grade uploading for a course (importing from a csv file).

2. A stored procedure to compute the current CGPA of the student.
