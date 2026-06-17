# custom-review-intervals Specification

## Purpose
TBD - created by archiving change comprehensive-optimization. Update Purpose after archive.
## Requirements
### Requirement: User can customize review intervals
The system SHALL allow users to customize the number of days between the base date and each review event.

#### Scenario: User opens interval settings
- **WHEN** user opens the settings or configuration panel
- **THEN** the system displays three input fields for the review intervals
- **AND** the default values are 3, 7, and 30 days
- **AND** the system validates that intervals are positive integers

#### Scenario: User modifies intervals
- **WHEN** user changes the interval values (e.g., to 1, 3, 7 days)
- **AND** user confirms the changes
- **THEN** the system saves the new interval settings
- **AND** updates the preview to reflect the new intervals
- **AND** the new intervals are used for future review schedule creations

#### Scenario: User sets invalid intervals
- **WHEN** user enters a non-positive number or zero
- **THEN** the system prevents saving
- **AND** displays an error message explaining that intervals must be at least 1 day

#### Scenario: Intervals persist across sessions
- **WHEN** user restarts the application
- **THEN** the system remembers the previously configured intervals
- **AND** applies them to the preview and new creations

### Requirement: Default intervals are maintained
The system SHALL provide a way to reset intervals to the default values.

#### Scenario: User resets to defaults
- **WHEN** user clicks a "恢复默认" button
- **THEN** the system resets intervals to 3, 7, and 30 days
- **AND** saves the defaults
- **AND** updates the preview accordingly

