## ADDED Requirements

### Requirement: System maintains a history of created review schedules
The system SHALL maintain a persistent list of recently created review schedules, viewable by the user.

#### Scenario: User creates a review schedule
- **WHEN** user successfully creates a review schedule
- **THEN** the system saves the title, base date, and creation timestamp to history
- **AND** the history is persisted across application restarts

#### Scenario: User views history
- **WHEN** user opens the history panel or section
- **THEN** the system displays a list of recently created review schedules
- **AND** each entry shows the title, base date, and review dates
- **AND** entries are ordered by creation time, most recent first

#### Scenario: History limit is reached
- **WHEN** the history reaches the maximum limit (20 entries)
- **THEN** the oldest entry is automatically removed
- **AND** the new entry is added to the top of the list

### Requirement: History entries are actionable
The system SHALL allow users to interact with history entries.

#### Scenario: User selects a history entry
- **WHEN** user clicks on a history entry
- **THEN** the system populates the title field with the entry's title
- **AND** sets the date picker to the entry's base date
- **AND** updates the preview accordingly

#### Scenario: User clears history
- **WHEN** user clicks a "清除历史" button
- **THEN** the system removes all history entries
- **AND** displays a confirmation prompt before clearing
