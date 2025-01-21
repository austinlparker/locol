# locol

Manage your local OpenTelemetry collectors on macOS.

## Features

- Configure and run multiple OpenTelemetry collectors.
- View collector metrics and logs in real-time
- Easily add pre-configured snippets to your collector config
- Generate test data to validate your collector setup
- Menubar-based interface for quick access to all features

## Getting Started

1. Install locol using the provided DMG file
2. Launch the application - it will appear in your menubar with the locol icon
3. Click the menubar icon to access the application menu
4. Start by opening Settings to configure your first collector

## Application Overview

### MenuBar Interface

The application runs in your menubar, providing quick access to:
- Start/Stop individual collectors
- View metrics and logs for each collector
- Edit collector configurations
- Access application settings
- Launch the data generator
- Quick status overview of all configured collectors

#### How to Use the MenuBar
1. Click the locol icon in your menubar to open the menu
2. Each configured collector appears as a submenu
3. For each collector, you can:
   - Click Start/Stop to control the collector
   - Select "View Metrics & Logs" to monitor activity
   - Choose "Edit Config" to modify the configuration
4. Use the Settings option to manage collectors
5. Access the Data Generator to test your setup

### Views

#### Settings
- Configure global application settings
- Add and remove collectors
- Import and manage collector configurations
- Configure default behaviors and paths

##### How to Use Settings
1. Access Settings from the menubar menu
2. To add a new collector:
   - Click the "+" button
   - Enter a name for your collector
   - Choose a configuration template or start from scratch
   - Set the collector's working directory
3. To remove a collector:
   - Select the collector from the list
   - Click the "-" button
4. Manage global settings:
   - Configure default paths
   - Set startup preferences
   - Manage configuration templates

#### Config Editor
- Full-featured configuration editor for each collector
- Edit YAML configurations directly
- Add pre-configured snippets for common scenarios
- Validate configurations before applying

##### How to Use the Config Editor
1. Open the Config Editor from a collector's menubar submenu
2. Edit your YAML configuration:
   - Use the built-in editor for direct YAML editing
   - Click "Add Snippet" to insert pre-configured blocks
   - The editor provides syntax highlighting and validation
3. Save your changes:
   - Click "Save" to apply the configuration
   - The editor will validate your YAML before saving
   - If validation fails, errors will be highlighted

#### Metrics & Logs Viewer
- Real-time view of collector metrics
- Live log streaming
- Filter and search capabilities
- Performance monitoring and troubleshooting

##### How to Use the Metrics & Logs Viewer
1. Open the viewer from a collector's menubar submenu
2. Monitor metrics:
   - View real-time metric updates
   - Use the search bar to filter metrics
   - Click on metrics to see detailed information
3. View logs:
   - Scroll through live log output
   - Use log level filters to focus on specific types
   - Search logs using the search bar
4. Troubleshooting:
   - Use the performance metrics tab to identify issues
   - Export logs for sharing or analysis

#### Data Generator
- Generate test data to validate collector setups
- Configure custom data generation patterns
- Simulate various data scenarios
- Verify collector processing

##### How to Use the Data Generator
1. Open the Data Generator from the menubar menu
2. Configure your test data:
   - Select the data type (metrics, traces, logs)
   - Choose a generation pattern
   - Set the data volume and frequency
3. Start generating:
   - Click "Start" to begin data generation
   - Monitor the results in the Metrics & Logs Viewer
   - Adjust parameters in real-time
4. Validate collection:
   - Use the Metrics & Logs Viewer to confirm data is being collected
   - Check for any processing errors or delays

## Development

### Requirements

- macOS 14 or later
- Xcode 15 or later
- Apple Developer account for signing and notarization

### Building

Clone the repository and open `locol.xcodeproj` in Xcode. You can then build and run the project directly from Xcode.

### CI/CD

The project uses GitHub Actions for continuous integration and deployment. The workflow:

1. Builds and tests the application on every push and pull request
2. On the main branch, additionally:
   - Creates a signed and notarized DMG
   - Uploads the DMG as a build artifact

Required GitHub secrets for CI/CD:

- `BUILD_CERTIFICATE_BASE64`: Developer ID certificate (base64 encoded)
- `MAC_DEV_CERTIFICATE_BASE64`: Mac Development certificate (base64 encoded)
- `CERT_PASSWORD`: Password for both certificates
- `APPLE_ID`: Apple ID email
- `TEAM_ID`: Apple Developer Team ID
- `APP_SPECIFIC_PASSWORD`: App-specific password for Apple ID

## Project Structure

- `Models/`: Data models and business logic
  - Collector management
  - Metrics processing
  - Configuration handling
  - Data generation
- `Views/`: SwiftUI views and view models
  - Main application views
  - Component views
  - Custom controls
- `Helpers/`: Extensions and utility functions
- `Resources/`: Assets and configuration templates
