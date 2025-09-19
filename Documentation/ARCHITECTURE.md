# IntuneManager - Architecture Documentation

## Overview
IntuneManager is a cross-platform Apple app (macOS, iOS, iPadOS) for managing Microsoft Intune devices with a focus on efficient app-to-device-group assignment operations.

## Technology Stack

### Core Technologies
- **SwiftUI**: Cross-platform UI framework for macOS 13+, iOS 16+, iPadOS 16+
- **Swift 5.9+**: Modern Swift with async/await concurrency
- **Microsoft Graph API Beta**: For Intune management operations
- **MSAL iOS**: Microsoft Authentication Library for secure OAuth2/OIDC authentication
- **Swift Data**: For local data persistence and caching (iOS 17+/macOS 14+)
- **Combine**: For reactive programming patterns where appropriate

## Architecture Pattern: MVVM-C (Model-View-ViewModel-Coordinator)

### Core Principles
1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data
2. **Testability**: All business logic isolated in testable ViewModels and Services
3. **Modularity**: Feature-based modules that can be developed independently
4. **Platform Adaptivity**: Single codebase with platform-specific optimizations
5. **Performance**: Aggressive caching, batch operations, and optimistic UI updates

## Module Structure

```
IntuneManager/
├── App/                           # App lifecycle and configuration
│   ├── IntuneManagerApp.swift
│   ├── AppDelegate.swift
│   └── Configuration/
│       ├── Environment.swift
│       └── AppConstants.swift
│
├── Core/                          # Core functionality and shared code
│   ├── Authentication/
│   │   ├── AuthManager.swift
│   │   ├── MSALConfiguration.swift
│   │   └── TokenManager.swift
│   │
│   ├── Networking/
│   │   ├── GraphAPIClient.swift
│   │   ├── NetworkManager.swift
│   │   ├── APIEndpoints.swift
│   │   └── ErrorHandling.swift
│   │
│   ├── DataLayer/
│   │   ├── Models/
│   │   │   ├── Device.swift
│   │   │   ├── Application.swift
│   │   │   ├── DeviceGroup.swift
│   │   │   └── Assignment.swift
│   │   ├── Repository/
│   │   │   └── IntuneRepository.swift
│   │   └── Cache/
│   │       ├── CacheManager.swift
│   │       └── SwiftDataModels/
│   │
│   └── Extensions/
│       ├── View+Extensions.swift
│       └── Error+Extensions.swift
│
├── Features/                      # Feature modules
│   ├── Dashboard/
│   │   ├── ViewModels/
│   │   │   └── DashboardViewModel.swift
│   │   └── Views/
│   │       ├── DashboardView.swift
│   │       └── DashboardWidgets/
│   │
│   ├── Devices/
│   │   ├── ViewModels/
│   │   │   ├── DeviceListViewModel.swift
│   │   │   └── DeviceDetailViewModel.swift
│   │   └── Views/
│   │       ├── DeviceListView.swift
│   │       ├── DeviceDetailView.swift
│   │       └── DeviceRowView.swift
│   │
│   ├── Applications/
│   │   ├── ViewModels/
│   │   │   ├── AppListViewModel.swift
│   │   │   └── AppDetailViewModel.swift
│   │   └── Views/
│   │       ├── AppListView.swift
│   │       ├── AppDetailView.swift
│   │       └── AppAssignmentView.swift
│   │
│   ├── Groups/
│   │   ├── ViewModels/
│   │   │   └── GroupManagementViewModel.swift
│   │   └── Views/
│   │       ├── GroupListView.swift
│   │       └── GroupSelectionView.swift
│   │
│   └── BulkAssignment/            # Key feature for efficient assignments
│       ├── ViewModels/
│       │   ├── BulkAssignmentViewModel.swift
│       │   └── AssignmentQueueManager.swift
│       └── Views/
│           ├── BulkAssignmentView.swift
│           ├── AssignmentProgressView.swift
│           └── AssignmentReviewView.swift
│
├── Services/                      # Business logic services
│   ├── DeviceService.swift
│   ├── ApplicationService.swift
│   ├── GroupService.swift
│   ├── AssignmentService.swift
│   └── SyncService.swift
│
├── Shared/                        # Shared UI components
│   ├── Components/
│   │   ├── LoadingView.swift
│   │   ├── ErrorView.swift
│   │   ├── SearchBar.swift
│   │   └── FilterView.swift
│   │
│   └── Modifiers/
│       ├── PlatformAdaptive.swift
│       └── ConditionalModifier.swift
│
├── Resources/
│   ├── Localizable.strings
│   └── Assets.xcassets
│
└── Utilities/
    ├── Logger.swift
    ├── Analytics.swift
    └── PerformanceMonitor.swift
```

## Data Flow Architecture

### 1. Authentication Flow
```
User Login → MSAL Auth → Token Acquired → Store in Keychain → GraphAPI Ready
```

### 2. Data Synchronization Strategy
- **Initial Load**: Fetch all devices, apps, and groups with pagination
- **Incremental Sync**: Use delta queries where available
- **Cache Strategy**:
  - SwiftData for persistent storage
  - In-memory cache for active session
  - TTL-based cache invalidation (configurable)
- **Offline Support**: Queue operations when offline, sync when connected

### 3. Bulk Assignment Optimization
```
Select Apps → Select Groups → Preview Changes → Batch API Calls → Progress Tracking → Completion
```
- Batch operations in groups of 20 (Graph API limit)
- Parallel execution where possible
- Rollback capability on partial failures
- Progress indication with cancellation

## Platform-Specific Adaptations

### macOS
- Menu bar integration
- Keyboard shortcuts
- Multi-window support
- Sidebar navigation
- Contextual menus
- Drag-and-drop support

### iOS/iPadOS
- Tab bar navigation (iOS)
- Split view navigation (iPadOS)
- Swipe gestures
- Pull-to-refresh
- Haptic feedback
- Widget extensions

## Key Design Patterns

### 1. Repository Pattern
Abstracts data access, allowing switching between Graph API and cached data seamlessly.

### 2. Coordinator Pattern
Manages navigation flow and deep linking, especially important for complex workflows.

### 3. Observer Pattern
Uses Combine publishers for reactive updates across ViewModels.

### 4. Factory Pattern
Creates appropriate service instances based on configuration and platform.

### 5. Strategy Pattern
Different sync strategies based on network conditions and data volume.

## Performance Optimizations

### 1. Lazy Loading
- Load device/app details on demand
- Paginate large lists (50 items per page)
- Virtual scrolling for large datasets

### 2. Intelligent Caching
- Cache Graph API responses
- Implement ETags for conditional requests
- Background refresh for frequently accessed data

### 3. Batch Operations
- Combine multiple API calls using Graph batch endpoint
- Queue assignment operations for bulk processing
- Implement retry logic with exponential backoff

### 4. UI Optimizations
- Debounce search inputs
- Throttle scroll events
- Use task priorities for concurrent operations
- Implement optimistic UI updates

## Security Considerations

### 1. Authentication
- MSAL with PKCE flow
- Biometric authentication for app access
- Token refresh handling
- Secure token storage in Keychain

### 2. Data Protection
- Encrypt sensitive data at rest
- Certificate pinning for API calls
- App Transport Security enforcement
- No logging of sensitive information

### 3. Permissions
- Principle of least privilege for Graph API scopes
- Role-based access control within app
- Audit logging for administrative actions

## Error Handling Strategy

### 1. Network Errors
- Automatic retry with exponential backoff
- Offline queue for failed operations
- User-friendly error messages

### 2. API Errors
- Graceful degradation
- Fallback to cached data when appropriate
- Clear error states with recovery actions

### 3. Authentication Errors
- Automatic token refresh
- Re-authentication prompts
- Session timeout handling

## Testing Strategy

### 1. Unit Tests
- ViewModels: 80% coverage minimum
- Services: 90% coverage minimum
- Utilities: 100% coverage

### 2. Integration Tests
- API client with mocked responses
- Repository layer with in-memory database
- Authentication flow with test tenant

### 3. UI Tests
- Critical user journeys
- Platform-specific features
- Accessibility compliance

## Future Extensibility

### Planned Modules
1. **Policy Management**: Configure and deploy device policies
2. **Compliance Reporting**: Device compliance dashboards
3. **User Management**: User enrollment and profile management
4. **Analytics Dashboard**: Usage statistics and trends
5. **Automation Rules**: Conditional assignment based on device properties
6. **Export/Import**: Bulk configuration management

### Extension Points
- Plugin architecture for custom modules
- Webhook support for external integrations
- Custom reporting templates
- Third-party MDM integration

## Development Workflow

### 1. Environment Setup
- Development, Staging, Production configurations
- Feature flags for gradual rollout
- A/B testing infrastructure

### 2. CI/CD Pipeline
- Automated testing on PR
- Beta distribution via TestFlight
- Staged rollout via App Store Connect

### 3. Monitoring
- Crashlytics integration
- Performance monitoring
- Usage analytics
- Error tracking

## Dependencies Management

### Swift Package Manager
All dependencies managed via SPM for better integration with Xcode Cloud.

### Key Dependencies
- MSAL (Microsoft Authentication)
- SwiftLint (Code quality)
- TelemetryDeck (Analytics)
- Alamofire (Networking backup)

## Conclusion

This architecture provides a solid foundation for a performant, maintainable, and extensible Intune management application. The modular structure allows for independent feature development while the shared core ensures consistency and code reuse across platforms.