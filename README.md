# Timetable Scheduler

An offline Flutter Desktop application designed for academic departments to efficiently generate and manage class timetables, faculty schedules, and master schedules with conflict detection and local storage support.

## Features

### Faculty Management

* Add, edit, and delete faculty members.
* Store faculty name and designation.
* Prevent deletion of faculty assigned to subjects.
* Import faculty data from Excel files.

### Subject Management

* Manage subjects for all academic years.
* Store:

  * Course Code
  * Course Title
  * Semester
  * Subject Type (Theory / Lab / Project / Additional)
  * Assigned Faculty Members
* Support up to three faculty members per subject.

### Timetable Generation

* Generate timetables for:

  * First Year
  * Second Year
  * Third Year
  * Fourth Year
* Configure weekly hours for each subject.
* Automatic conflict detection and validation.

### Scheduling Constraints

#### Hard Constraints

* A faculty member cannot teach multiple classes at the same time.
* Subject hours must be allocated exactly as specified.
* Faculty workload conflicts are prevented.
* Multiple assigned faculty members are considered occupied during a scheduled period.

#### Lab Constraints

* Lab sessions are scheduled as continuous blocks.
* Example:

  * 2-hour lab → 2 consecutive periods.
  * 3-hour lab → 3 consecutive periods.
  * 4-hour lab → 4 consecutive periods.

#### Optimization Rules

* Distribute subjects evenly throughout the week.
* Minimize consecutive periods of the same theory subject.
* Generate balanced schedules whenever possible.

### Timetable Views

#### Year-wise Timetables

* Individual timetable for each year.
* 5 working days.
* 8 periods per day.

#### Faculty Timetables

* Individual schedule for every faculty member.
* Displays:

  * Year
  * Course Code
  * Assigned Periods

#### Master Timetable

* Combined timetable of all years.
* Shows all courses running in each time slot.

### Export Options

* Export timetables as PDF.
* Export timetables as Excel (.xlsx).
* Store generated files locally.

### History Management

* Automatically save generated timetables.
* View previously generated schedules.
* Open PDF and Excel files directly.
* Delete old timetable records.

### Backup and Restore

* Backup database to a selected location.
* Restore database from a backup file.
* Preserve faculty, subjects, timetable inputs, and generated schedules.

## Technology Stack

### Frontend

* Flutter Desktop (Windows)

### State Management

* Riverpod

### Database

* SQLite
* sqflite_common_ffi

### File Management

* path_provider
* file_picker
* open_filex

### PDF Generation

* pdf
* printing

### Excel Generation

* excel

## Local Storage

All data is stored locally on the user's computer.

Stored data includes:

* Faculty records
* Subject records
* Timetable configurations
* Generated timetables
* PDF exports
* Excel exports
* History records

No internet connection is required.

## System Requirements

* Windows 10 or Windows 11
* Flutter 3.35+ (for development)
* Minimum 4 GB RAM
* 100 MB free storage

## Developer

**Rithick P**

Department of Robotics and Automation

Sri Ramakrishna Engineering College

Batch: 2023 – 2027

Version: 1.0.0

## License

This project is intended for academic and departmental use.
