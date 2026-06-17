## ADDED Requirements

### Requirement: System handles duplicate events gracefully
The system SHALL detect duplicate events by comparing title, date, and note content, and warn the user before creating.

#### Scenario: Duplicate events exist
- **WHEN** user attempts to create events
- **AND** one or more target dates already have events with the same title AND same date AND same note content
- **THEN** the system prevents creating duplicate events for those dates
- **AND** displays a warning message listing the dates with duplicates
- **AND** continues creating events for non-duplicate dates

#### Scenario: Same title but different date
- **WHEN** user creates events with a title that exists on a different date
- **THEN** the system does NOT treat it as a duplicate
- **AND** proceeds with normal creation

#### Scenario: No duplicates
- **WHEN** user creates events
- **AND** no duplicate events exist on target dates with matching title and note
- **THEN** the system displays a success message with all created dates

### Requirement: System creates three all-day review events
The system SHALL create three all-day events in the system's default calendar using a safe, non-optional date calculation.

#### Scenario: Events are created with correct properties
- **WHEN** events are created
- **THEN** each event is an all-day event (isAllDay = true)
- **AND** each event's note contains the review number label (e.g., "第1次复习")
- **AND** events are saved to the default calendar for new events
- **AND** date calculations use `guard let` instead of force unwrap
- **AND** if date calculation fails, the system displays an error and skips that event

### Requirement: System displays creation result
The system SHALL display the result using localized strings instead of hardcoded Chinese text.

#### Scenario: Successful creation
- **WHEN** all three events are created successfully
- **THEN** the system displays a localized success message with the list of created dates
- **AND** the system clears the title input field
- **AND** the system resets the date picker to today
- **AND** the system allows the user to create another review schedule immediately
- **AND** the success message is retrieved from Localizable.strings

#### Scenario: Empty title
- **WHEN** user attempts to create events with an empty title or title containing only whitespace
- **THEN** the system prevents creation
- **AND** displays a localized prompt asking the user to enter a valid title

#### Scenario: Title is too long
- **WHEN** user enters a title exceeding 100 characters
- **THEN** the system prevents creation
- **AND** displays a localized error message explaining the title length limit

### Requirement: System uses safe date calculation
The system SHALL calculate review dates using safe, non-optional operations.

#### Scenario: Date calculation succeeds
- **WHEN** the system calculates review dates from the base date
- **THEN** it uses `Calendar.date(byAdding:to:)` with `guard let` unwrap
- **AND** all three dates are successfully computed

#### Scenario: Date calculation fails
- **WHEN** the system attempts to calculate a review date and the calendar returns nil
- **THEN** the system logs an error
- **AND** skips that specific review date
- **AND** displays a warning to the user
- **AND** continues with the remaining dates

### Requirement: System uses localized strings for all UI text
The system SHALL retrieve all user-visible text from Localizable.strings.

#### Scenario: UI displays text
- **WHEN** any UI element displays text (labels, buttons, messages, prompts)
- **THEN** the text is retrieved via `NSLocalizedString` or SwiftUI's localization mechanism
- **AND** no hardcoded Chinese strings exist in the Swift source code
- **AND** all new text keys are added to Localizable.strings

### Requirement: NotificationCenter observer is properly managed
The system SHALL manage the NotificationCenter observer lifecycle to prevent memory leaks.

#### Scenario: ViewModel is deallocated
- **WHEN** the `ReviewViewModel` is deallocated
- **THEN** the NotificationCenter observer for `.createReviewSchedule` is removed
- **AND** no memory leak occurs

#### Scenario: Observer is added on initialization
- **WHEN** the `ReviewViewModel` is initialized
- **THEN** it adds an observer for `.createReviewSchedule`
- **AND** the observer token is stored as an instance property
- **AND** the observer is removed in `deinit`
