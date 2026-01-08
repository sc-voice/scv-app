# Privacy Policy

## Overview

SC-Voice is committed to protecting user privacy. This application is designed with privacy as a core principle—all data processing occurs locally on your device, and no information is transmitted to external servers.

## Data Collection

SC-Voice collects minimal data, exclusively for core application functionality. Importantly, **there is no explicit user identification system**. Instead, SC-Voice stores information on behalf of the user for local use only—organizing user-created cards, searches, and browsing history with internal identifiers that exist solely to structure data within the app.

### User-Collected Data

#### 1. Search Queries
- **What:** Text that users enter into search fields
- **How collected:** Through the SearchCardView interface
- **Storage:** Persisted locally via SwiftData on device
- **Purpose:** To enable search functionality and maintain search history
- **Tracking:** Not used for tracking
- **User control:** Users can clear search history manually

#### 2. Browsing History
- **What:** Sutta references (scripture identifiers) that users view
- **How collected:** Automatically when users select and view scriptures
- **Storage:** Persisted locally via SwiftData on device
- **Purpose:** To enable sutta viewer cards and maintain browsing history
- **Tracking:** Not used for tracking
- **User control:** Users can delete cards to clear history

#### 3. Card Preferences
- **What:** User-created search cards and sutta viewer cards with their configuration
- **How collected:** Automatically when users create and configure cards
- **Storage:** Persisted locally via SwiftData on device
- **Purpose:** To preserve user interface state and preferences across app sessions
- **Tracking:** Not used for tracking
- **User control:** Users can delete cards at any time

#### 4. Product Interaction
- **What:** General app usage patterns (which views users interact with within cards)
- **How collected:** Implicitly through normal app usage
- **Storage:** Persisted locally via SwiftData on device
- **Purpose:** To improve user experience and app stability
- **Tracking:** Not used for tracking
- **User control:** Users can delete card-specific interaction data by deleting the card; not shared with third parties

#### 5. User ID (Data Storage Identifiers)
- **What:** SC-Voice does not maintain an explicit user identifier. Instead, the app generates unique identifiers (UUIDs) for internal data organization when storing user-created cards and associated information on the device.
- **How collected:** Automatically generated when users create search cards, sutta viewer cards, or when the app stores search queries and browsing history associated with those cards.
- **Storage:** Persisted locally via SwiftData on device as part of the card and data record structure
- **Purpose:** To organize and link user-created data on behalf of the user for local app functionality only (e.g., matching a search query to its card, linking browsing history to a sutta viewer)
- **Tracking:** These identifiers have no tracking purpose and are never shared with third parties
- **User control:** Identifiers exist only while their associated data exists; deleting a card or clearing data removes all associated identifiers

## Data Storage

All collected data is stored **exclusively on your device** using SwiftData, Apple's local persistence framework. Data is never:

- Transmitted to external servers
- Shared with third parties
- Used for advertising or marketing
- Sold or monetized
- Accessed by developers or other parties

## Data Deletion

Users can delete personal data at any time:

1. **Search History:** Clear by deleting search cards or editing individual search queries
2. **Browsing History:** Clear by deleting sutta viewer cards
3. **Preferences:** Reset by reinstalling the application

Uninstalling the application removes all associated data from the device.

## Security

SC-Voice uses Apple's native SwiftData framework with device-level encryption. Data is protected by:

- iOS device-level encryption (automatically enabled)
- No external network transmission (eliminating transmission vulnerabilities)
- No external dependencies (minimizing attack surface)

## Third-Party Services

SC-Voice does not integrate with, transmit data to, or depend on any third-party services or analytics platforms. The application is entirely self-contained.

## Children's Privacy

SC-Voice is not targeted at children under 13. The application does not knowingly collect information from children under 13.

## Data Processing Location

All data processing occurs on the user's device. No processing occurs on external servers.

## Changes to Privacy Policy

This privacy policy may be updated to reflect changes in the application or regulatory requirements. Users will be notified of significant changes.

## Compliance

SC-Voice complies with:

- Apple App Store privacy requirements
- GDPR privacy principles
- CCPA privacy principles
- Other applicable privacy regulations

## Contact

For privacy-related questions or concerns, please visit:

**Project:** SC-Voice
**Repository:** https://github.com/buddhistcanon/sc-voice
**Issues:** https://github.com/buddhistcanon/sc-voice/issues

## Data Categories (Apple Privacy Manifest)

The following data types are collected for app functionality purposes:

| Category | Collected | Linked | Tracking | Purpose |
|----------|-----------|--------|----------|---------|
| User ID | Yes | No | No | App Functionality |
| Search History | Yes | No | No | App Functionality |
| Browsing History | Yes | No | No | App Functionality |
| Product Interaction | Yes | No | No | App Functionality |

---

**Last Updated:** January 2026
**Version:** 1.0
