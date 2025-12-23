# Architecture

## System Overview

SMS Gateway is a multi-tenant SaaS application built with Flutter and Supabase, designed for enterprise-grade bulk SMS management.

## Tech Stack

- **Frontend:** Flutter 3.0+
- **Backend:** Supabase (PostgreSQL + REST API)
- **Authentication:** Supabase Auth
- **Database:** PostgreSQL 15
- **SMS Delivery:** Android SIM integration

## Database Architecture

### Schema Design

```
┌─────────────────────────────────────────┐
│         public (Control Plane)          │
├─────────────────────────────────────────┤
│ • products                              │
│ • clients (tenants)                     │
│ • global_users                          │
│ • client_product_access                 │
│ • product_subscriptions                 │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      sms_gateway (Application Data)     │
├─────────────────────────────────────────┤
│ • users                                 │
│ • contacts                              │
│ • groups                                │
│ • group_members                         │
│ • sms_logs                              │
│ • api_keys                              │
│ • audit_logs                            │
│ • settings                              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         auth (Supabase Built-in)        │
├─────────────────────────────────────────┤
│ • users                                 │
│ • sessions                              │
└─────────────────────────────────────────┘
```

### Multi-Tenancy

- **Schema Isolation:** Each tenant's data is isolated using `tenant_id`
- **Row Level Security (RLS):** PostgreSQL RLS policies enforce tenant boundaries
- **Access Control:** `client_product_access` table manages user-tenant-product relationships

## Application Architecture

### Layer Structure

```
┌──────────────────────────────────────┐
│         Presentation Layer           │
│  (Screens, Widgets, UI Components)   │
└──────────────┬───────────────────────┘
               │
┌──────────────▼───────────────────────┐
│          Business Logic              │
│     (Services, State Management)     │
└──────────────┬───────────────────────┘
               │
┌──────────────▼───────────────────────┐
│           Data Layer                 │
│   (API Calls, Local Storage, SMS)   │
└──────────────────────────────────────┘
```

### Key Components

1. **Authentication System**
   - Email/Password authentication via Supabase Auth
   - Session management
   - User profile management

2. **Contact Management**
   - CRUD operations for contacts
   - CSV import support
   - Phone number validation

3. **Group Management**
   - Create and manage contact groups
   - Add/remove members
   - Bulk operations

4. **SMS Engine**
   - Android SMS Manager integration
   - Queue management
   - Delivery tracking
   - Rate limiting

5. **API Service**
   - REST API integration
   - API key authentication
   - Request/response logging

## Security

### Authentication & Authorization

- JWT tokens for API authentication
- Row Level Security (RLS) on all tables
- Tenant isolation at database level
- API key management for external integrations

### Data Protection

- Encrypted connections (HTTPS/TLS)
- Secure password hashing
- Audit logging for sensitive operations
- No PII stored in logs

## Scalability

### Database Optimization

- Indexes on `tenant_id`, `user_id`, and foreign keys
- Efficient queries with tenant filtering
- Connection pooling via Supabase

### Performance

- Lazy loading for large datasets
- Pagination for lists
- Background processing for bulk SMS
- Local caching where appropriate

## Deployment

### Development
```bash
flutter run
```

### Production (Android)
```bash
flutter build apk --release
```

### Environment Configuration
- Supabase credentials via constants
- Feature flags for gradual rollout
- Environment-specific configurations

## Future Enhancements

- [ ] iOS support with SMS provider integration
- [ ] Real-time delivery reports
- [ ] Advanced analytics dashboard
- [ ] Template management
- [ ] Scheduled SMS campaigns
- [ ] Webhook integrations
- [ ] Multi-language support
