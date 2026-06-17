## ADDED Requirements

### Requirement: User can undo the most recent review creation
The system SHALL allow the user to undo the most recently created review schedule, removing all three events from the calendar.

#### Scenario: User creates events and then clicks undo
- **WHEN** user successfully creates a review schedule
- **AND** user clicks the "撤销" button
- **THEN** the system removes all three events from the calendar
- **AND** displays a success message indicating the undo was completed
- **AND** the undo button is hidden or disabled after successful undo

#### Scenario: Undo fails because events were manually deleted
- **WHEN** user clicks the "撤销" button
- **AND** one or more events no longer exist in the calendar (manually deleted by user)
- **THEN** the system removes any remaining events that still exist
- **AND** displays a warning message indicating which events were already deleted
- **AND** the undo button is disabled

#### Scenario: No creation to undo
- **WHEN** the application launches or after an undo is completed
- **THEN** the undo button is disabled or hidden
- **AND** no undo action is available until a new creation occurs

### Requirement: System tracks created events for undo
The system SHALL store the event identifiers of the most recently created review schedule to enable undo functionality.

#### Scenario: Events are created successfully
- **WHEN** the system successfully creates three review events
- **THEN** the system stores their event identifiers
- **AND** the undo button becomes enabled
- **AND** the stored identifiers are cleared after a successful undo or application restart

#### Scenario: Partial creation
- **WHEN** only some events are created successfully (e.g., 1 or 2 out of 3)
- **THEN** the system stores the identifiers of successfully created events
- **AND** the undo button is enabled for those events only
- **AND** the system allows the user to retry creating the failed events separately
