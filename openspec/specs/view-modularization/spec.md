# view-modularization Specification

## Purpose
TBD - created by archiving change comprehensive-optimization. Update Purpose after archive.
## Requirements
### Requirement: Main view is decomposed into subviews
The system SHALL decompose the monolithic `ContentView` into focused, single-responsibility subviews.

#### Scenario: Application renders correctly after refactoring
- **WHEN** user launches the application
- **THEN** all UI elements (title input, date picker, preview list, create button, result message, permission button) are displayed
- **AND** the layout and styling are identical to the pre-refactoring state
- **AND** all interactive elements function correctly

### Requirement: Title input is isolated in a subview
The system SHALL extract the title input section into a dedicated `TitleInputSection` view.

#### Scenario: User interacts with title input
- **WHEN** user types into the title field
- **THEN** the text is bound to the ViewModel's `title` property
- **AND** the view is reusable and independently testable

### Requirement: Date picker is isolated in a subview
The system SHALL extract the date picker section into a dedicated `DatePickerSection` view.

#### Scenario: User selects a date
- **WHEN** user selects a date in the picker
- **THEN** the date is bound to the ViewModel's `baseDate` property
- **AND** the preview updates automatically via the ViewModel
- **AND** the view handles the `onChange` logic internally

### Requirement: Review preview is isolated in a subview
The system SHALL extract the review date preview list into a dedicated `ReviewPreviewSection` view.

#### Scenario: Preview displays review dates
- **WHEN** the ViewModel's `reviewDates` changes
- **THEN** the preview list updates to show the three review dates
- **AND** each entry is labeled with the review number
- **AND** the view formats dates using the ViewModel's formatter

### Requirement: Action and result area is isolated in a subview
The system SHALL extract the create button, result message, and permission button into a dedicated `ActionSection` view.

#### Scenario: User clicks create button
- **WHEN** user clicks the create button
- **THEN** the view triggers the ViewModel's creation action
- **AND** the view displays loading state, result message, or permission button based on ViewModel state
- **AND** the undo button is displayed when a creation is available to undo

