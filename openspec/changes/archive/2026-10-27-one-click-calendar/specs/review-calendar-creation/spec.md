## ADDED Requirements

### Requirement: User can input title and base date
The system SHALL provide a user interface with a title text field and a date picker.

#### Scenario: User opens the application
- **WHEN** user launches the application
- **THEN** the system displays a window with a title input field and a date picker defaulting to today

#### Scenario: User enters title and selects date
- **WHEN** user types a title into the title field
- **AND** user selects a date from the date picker
- **THEN** the system accepts the input

### Requirement: System displays preview of review dates
The system SHALL display a preview list showing the three calculated review dates before creation.

#### Scenario: User selects a date
- **WHEN** user selects a date in the date picker
- **THEN** the system displays three dates: base date + 3 days, base date + 7 days, base date + 30 days
- **AND** each date is labeled with the corresponding review number ("第1次复习", "第2次复习", "第3次复习")

### Requirement: System requests calendar access permission
The system SHALL request permission to access the calendar before creating events.

#### Scenario: First-time launch
- **WHEN** user clicks the create button for the first time
- **AND** calendar permission has not been granted
- **THEN** the system displays a permission dialog with the usage description

#### Scenario: Permission granted
- **WHEN** user grants calendar permission
- **THEN** the system proceeds to create the review events

#### Scenario: Permission denied
- **WHEN** user denies calendar permission
- **THEN** the system displays an error message explaining that calendar access is required
- **AND** provides a button to open system settings

### Requirement: System creates three all-day review events
The system SHALL create three all-day events in the system's default calendar when the user clicks the create button.

#### Scenario: User clicks create button
- **WHEN** user clicks the "一键创建" button
- **THEN** the system creates three all-day events in the default calendar
- **AND** the first event is scheduled for base date + 3 days with title as entered
- **AND** the second event is scheduled for base date + 7 days with title as entered
- **AND** the third event is scheduled for base date + 30 days with title as entered

#### Scenario: Events are created with correct properties
- **WHEN** events are created
- **THEN** each event is an all-day event (isAllDay = true)
- **AND** each event's note contains the review number label ("第1次复习", "第2次复习", or "第3次复习")
- **AND** events are saved to the default calendar for new events

### Requirement: System handles duplicate events gracefully
The system SHALL allow creating events even if events with the same title exist on the same date, but warn the user.

#### Scenario: Duplicate events exist
- **WHEN** user attempts to create events
- **AND** one or more target dates already have events with the same title
- **THEN** the system creates the events anyway
- **AND** displays a warning message listing the dates with duplicates

#### Scenario: No duplicates
- **WHEN** user creates events
- **AND** no duplicate events exist on target dates
- **THEN** the system displays a success message with all created dates

### Requirement: System displays creation result
The system SHALL display the result of the creation operation to the user.

#### Scenario: Successful creation
- **WHEN** all three events are created successfully
- **THEN** the system displays a success message with the list of created dates
- **AND** the system clears the title input field
- **AND** the system resets the date picker to today
- **AND** the system allows the user to create another review schedule immediately

#### Scenario: User returns from system settings
- **WHEN** user returns from system settings after enabling calendar permission
- **THEN** the system detects the new authorization status
- **AND** updates the UI to allow event creation
- **AND** automatically proceeds with the pending creation if the user had clicked create before

#### Scenario: Partial failure
- **WHEN** one or more events fail to create
- **THEN** the system displays an error message indicating which events failed
- **AND** shows the specific error reason
- **AND** the system allows the user to retry creating the failed events
- **AND** the system retains the successfully created events (no rollback)

### Requirement: System handles edge cases
The system SHALL handle edge cases gracefully.

#### Scenario: Default calendar is unavailable
- **WHEN** the system attempts to create events
- **AND** the default calendar for new events is nil or unavailable
- **THEN** the system displays an error message guiding the user to check calendar settings

#### Scenario: Empty title
- **WHEN** user attempts to create events with an empty title
- **THEN** the system prevents creation
- **AND** displays a prompt asking the user to enter a title

#### Scenario: Date calculation across month boundary
- **WHEN** base date is January 31
- **THEN** base date + 30 days shall be March 1 (or March 2 in leap year)

#### Scenario: Date calculation across year boundary
- **WHEN** base date is December 31
- **THEN** base date + 3 days shall be January 3 of the next year

#### Scenario: Date calculation on leap year February
- **WHEN** base date is February 28 in a leap year
- **THEN** base date + 3 days shall be March 2
