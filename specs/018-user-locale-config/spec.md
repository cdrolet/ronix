# Feature Specification: User Locale Configuration

**Feature Branch**: `018-user-locale-config`\
**Created**: 2025-11-15\
**Status**: Ready for Implementation\
**Input**: User description: "additional user configuration: User configuration should include: - languages: an array listing all languages - keyboard_layout: an array listing all layouts - timezone - locale for time, metrics, etc.. so platform can set settings accordingly to this config as first implementation, update darwin setting to take these in consideration"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure Language Preferences (Priority: P1)

A user wants to specify their language preferences (e.g., English, French, Spanish) in their user configuration, and have the system automatically configure all language-related settings across the platform.

**Why this priority**: This is the most fundamental localization setting. Without language configuration, users cannot effectively use the system in their preferred language. This provides immediate, visible value.

**Independent Test**: Can be fully tested by adding a `languages` array to user config, building the configuration, and verifying that the platform's language settings match the specified preferences. Delivers value by allowing multilingual users to work in their preferred language without manual system configuration.

**Acceptance Scenarios**:

1. **Given** a user config without language settings, **When** user adds `languages = ["en-US" "fr-CA"]`, **Then** the system's language preferences are set to English (US) as primary and French (Canadian) as secondary
1. **Given** a user config with single language, **When** user adds multiple languages in priority order, **Then** the system respects the priority order for fallback languages
1. **Given** a darwin system configuration, **When** user config specifies languages, **Then** macOS system language preferences reflect the user's language array

______________________________________________________________________

### User Story 2 - Configure Keyboard Layout (Priority: P2)

A user wants to specify keyboard layouts (e.g., US, Canadian French, Dvorak) in their user configuration, and have the system automatically configure available keyboard layouts.

**Why this priority**: Keyboard layout is essential for productivity but not as critical as language for basic system use. Users can manually switch layouts as a workaround, but automated configuration significantly improves user experience.

**Independent Test**: Can be fully tested by adding a `keyboardLayout` array to user config, building the configuration, and verifying that the specified keyboard layouts are available and configured in the correct order.

**Acceptance Scenarios**:

1. **Given** a user config, **When** user adds `keyboardLayout = ["us" "canadian-french"]` using platform-agnostic names, **Then** both keyboard layouts are available on the system
1. **Given** multiple keyboard layouts configured, **When** user specifies layout order, **Then** the first layout is set as the default
1. **Given** a darwin system, **When** user config specifies keyboard layouts with agnostic names, **Then** platform translates them to platform-specific identifiers (e.g., "us" → "com.apple.keylayout.US") and configures macOS keyboard layout settings

______________________________________________________________________

### User Story 3 - Configure Timezone (Priority: P1)

A user wants to specify their timezone (e.g., "America/Toronto", "Europe/Paris") in their user configuration, and have the system automatically set the timezone.

**Why this priority**: Timezone is critical for accurate time display, scheduling, and time-based operations. Incorrect timezone can cause serious usability issues with calendars, logs, and timestamps.

**Independent Test**: Can be fully tested by setting `timezone = "America/Toronto"` in user config, building the configuration, and verifying that the system timezone matches the specified value.

**Acceptance Scenarios**:

1. **Given** a user config, **When** user sets `timezone = "America/Toronto"`, **Then** the system timezone is set to America/Toronto
1. **Given** a system with different timezone, **When** user config is applied with new timezone, **Then** the system timezone is updated to match the config
1. **Given** a darwin system, **When** user specifies timezone, **Then** macOS timezone settings reflect the user's configuration

______________________________________________________________________

### User Story 4 - Configure Regional Locale (Priority: P2)

A user wants to specify their regional locale preferences for time format, date format, number format, measurement units, and currency in their user configuration.

**Why this priority**: Regional settings affect how information is displayed but don't prevent system use. Users can work with non-preferred formats, but correct locale settings improve user experience and prevent confusion.

**Independent Test**: Can be fully tested by setting `locale = "en_CA.UTF-8"` in user config, building the configuration, and verifying that date formats, time formats, and measurement units match Canadian conventions.

**Acceptance Scenarios**:

1. **Given** a user config, **When** user sets `locale = "en_CA.UTF-8"`, **Then** the system displays dates in Canadian format (YYYY-MM-DD), uses metric measurements, and formats currency as CAD
1. **Given** a US locale, **When** user sets locale to European format, **Then** system displays 24-hour time and metric measurements
1. **Given** a darwin system, **When** user specifies locale, **Then** macOS regional settings reflect the user's locale preferences

______________________________________________________________________

### Edge Cases

- What happens when a user specifies an invalid timezone (e.g., "Invalid/Timezone")? System should validate timezone values and provide clear error messages.
- What happens when a user specifies an empty languages array? System should fall back to platform defaults or require at least one language.
- What happens when a user specifies a keyboard layout that doesn't exist on the platform? System should validate available layouts or skip invalid entries with warnings.
- What happens when locale conflicts with language settings (e.g., language="en-US" but locale="fr_CA.UTF-8")? System allows independent configuration. Optionally logs a warning if the language portion of locale doesn't appear in the languages array.
- What happens when multiple users on the same system specify different locales? System should maintain per-user settings without interference.
- What happens when a user specifies a platform-agnostic keyboard layout name that has no mapping for the current platform? System should provide clear error message listing available layouts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: User configuration MUST accept a `languages` field containing an ordered array of language codes (e.g., ["en-US", "fr-CA"])
- **FR-002**: User configuration MUST accept a `keyboardLayout` field containing an ordered array of platform-agnostic keyboard layout identifiers (e.g., ["us", "canadian-french", "dvorak"])
- **FR-003**: User configuration MUST accept a `timezone` field containing an IANA timezone identifier (e.g., "America/Toronto")
- **FR-004**: User configuration MUST accept a `locale` field containing a locale identifier (e.g., "en_CA.UTF-8")
- **FR-005**: System MUST allow independent configuration of `languages` and `locale` fields without enforcing consistency
- **FR-006**: System MAY optionally log a warning when the language portion of `locale` does not appear in the `languages` array
- **FR-007**: System MUST use platform defaults when user does not specify locale settings (backward compatibility)
- **FR-008**: Platform library MUST provide a keyboard layout translation layer that maps platform-agnostic names to platform-specific identifiers
- **FR-009**: Darwin platform settings MUST consume language configuration from user config and apply to system language preferences
- **FR-010**: Darwin platform settings MUST translate platform-agnostic keyboard layout names to darwin-specific identifiers (e.g., "us" → "com.apple.keylayout.US") and configure available keyboard layouts
- **FR-011**: Darwin platform settings MUST consume timezone configuration from user config and set system timezone
- **FR-012**: Darwin platform settings MUST consume locale configuration from user config and apply to regional settings (date format, time format, measurements, currency)
- **FR-013**: System MUST validate timezone values against IANA timezone database
- **FR-014**: System MUST validate keyboard layout names against known platform-agnostic identifiers and provide clear error messages for unknown layouts
- **FR-015**: System MUST preserve existing user configuration structure and integrate locale settings alongside existing fields (name, email, fullName)
- **FR-016**: System MUST maintain multi-user isolation - one user's locale settings MUST NOT affect another user's settings
- **FR-017**: Configuration changes MUST be declarative and reproducible across system rebuilds

### Key Entities

- **User Configuration**: Represents per-user settings including locale preferences. Attributes: `name`, `email`, `fullName`, `languages` (array of language codes), `keyboardLayout` (array of platform-agnostic layout names), `timezone` (IANA timezone string), `locale` (POSIX locale string). All locale fields are optional - system uses platform defaults when not specified.
- **Platform Settings Module**: Consumes user configuration and translates locale preferences into platform-specific system settings. For darwin: maps to macOS system preferences via nix-darwin modules. Includes keyboard layout translation layer.
- **Keyboard Layout Translation Layer**: Maps platform-agnostic keyboard layout names (e.g., "us", "canadian-french") to platform-specific identifiers (e.g., "com.apple.keylayout.US" for darwin). Provides validation and clear error messages for unknown layouts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can add locale fields to their user configuration and successfully build the system without errors (100% success rate)
- **SC-002**: After applying configuration, system timezone matches user-specified timezone value (verified via system timezone query)
- **SC-003**: After applying configuration, system language preferences match user-specified languages in correct priority order (verified via system language query)
- **SC-004**: After applying configuration, keyboard layouts are available and configured in user-specified order (verified via keyboard layout list)
- **SC-005**: After applying configuration, regional settings (date format, time format, measurements) match user-specified locale (verified via system regional settings)
- **SC-006**: Multiple users with different locale settings can coexist on the same system without conflicts (verified by building multi-user configurations)
- **SC-007**: User with no locale settings specified continues to work with platform defaults (backward compatibility - 100% of existing configs build successfully)

### Design Decisions

The following decisions were made during specification:

1. **Language/Locale Independence**: System allows independent configuration of `languages` and `locale` fields. Users can specify UI language separately from regional formatting preferences. Optional warning when locale language doesn't match any language in the languages array.

1. **Default Behavior**: When user doesn't specify locale settings, system uses platform defaults. This ensures backward compatibility and allows optional configuration.

1. **Platform-Agnostic Keyboard Layouts**: Keyboard layout identifiers use platform-agnostic naming (e.g., "us", "canadian-french"). Platform library provides translation layer to map these to platform-specific identifiers (e.g., "com.apple.keylayout.US" for darwin).
