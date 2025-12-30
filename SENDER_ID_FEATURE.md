# Sender ID Management Feature

## Overview
The Sender ID Management feature allows customers to request custom Sender IDs for their SMS messages. A Sender ID is the name that appears as the sender of an SMS (e.g., "MYBANK", "ACME", "ALERT").

## User Flow

### 1. Request Sender ID
- Navigate to **Settings** → **Sender ID Management**
- Fill in the request form:
  - **Desired Sender ID**: Max 11 alphanumeric characters (e.g., "MYCOMPANY")
  - **Business/Organization Name**: Full legal business name
  - **Purpose of Use**: Why you need the Sender ID (marketing, notifications, alerts)
  - **Contact Phone Number**: Your contact number for verification
- Click **Submit Request**

### 2. Admin Review
- Request goes to admin for review
- Admin checks:
  - Business legitimacy
  - Sender ID availability
  - Compliance with regulations
- Approval typically takes 1-2 business days

### 3. Status Updates
- **Pending**: Awaiting admin review
- **Approved**: Approved but not yet active
- **Rejected**: Request denied (with reason in admin notes)
- **Active**: Approved and ready to use

### 4. Using Approved Sender ID
- Once approved and active, the Sender ID can be used in SMS sending
- Configure in Settings → SMS Channel settings

## Database Schema

### Table: `sms_gateway.sender_id_requests`

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `tenant_id` | uuid | Tenant who requested |
| `user_id` | uuid | User who submitted request |
| `sender_id` | varchar(11) | Requested Sender ID |
| `business_name` | varchar(255) | Business name |
| `purpose` | text | Purpose of use |
| `contact_phone` | varchar(20) | Contact number |
| `status` | varchar(20) | pending/approved/rejected/active |
| `admin_notes` | text | Admin comments |
| `reviewed_by` | uuid | Admin who reviewed |
| `reviewed_at` | timestamp | Review timestamp |
| `created_at` | timestamp | Request creation time |
| `updated_at` | timestamp | Last update time |

## Setup Instructions

### 1. Database Migration
Run the SQL migration in Supabase SQL Editor:
```bash
database/sender_id_requests_table.sql
```

This will:
- Create the `sender_id_requests` table
- Set up RLS policies
- Create indexes for performance
- Add auto-update trigger

### 2. Test the Feature
1. Open app and navigate to Settings
2. Click "Sender ID Management"
3. Fill in the form with test data:
   - Sender ID: TESTCO
   - Business Name: Test Company Inc
   - Purpose: Testing the Sender ID feature
   - Contact: +1234567890
4. Submit the request
5. Check Supabase → Table Editor → `sms_gateway.sender_id_requests`
6. Verify the request was created with status "pending"

### 3. Admin Panel (Future Enhancement)
Create an admin panel to:
- View all pending requests
- Approve/reject requests
- Add admin notes
- Activate approved Sender IDs
- View request history

## Benefits

### For Customers
- ✅ Professional brand identity in SMS
- ✅ Increased trust and recognition
- ✅ Better delivery rates
- ✅ Enhanced customer engagement

### For Business
- ✅ Revenue opportunity (charge for custom Sender IDs)
- ✅ Better customer retention
- ✅ Compliance with regulations
- ✅ Controlled approval process

## Pricing Strategy (Suggested)
- **Standard Sender ID**: Free (random numbers/default)
- **Custom Sender ID**: One-time fee ($50-$100) + monthly ($10-$20)
- **Premium Sender ID**: Higher pricing for premium names
- **Enterprise**: Multiple Sender IDs with dedicated support

## Future Enhancements
1. **Admin Dashboard**: Review and approve requests
2. **Email Notifications**: Notify customers when status changes
3. **Sender ID Library**: Pre-approved generic Sender IDs
4. **Multi-Sender ID**: Allow multiple Sender IDs per tenant
5. **Analytics**: Track SMS performance by Sender ID
6. **Auto-Renewal**: Subscription management for Sender IDs
7. **Bulk Import**: Import existing Sender IDs for migration

## Technical Notes
- Sender IDs are limited to 11 characters (telecom standard)
- Alphanumeric only (A-Z, 0-9)
- Case-insensitive (stored as uppercase)
- Requires admin approval for security
- RLS ensures tenant isolation
- Auto-update timestamp on changes

## Support
For issues or questions:
1. Check Supabase logs for errors
2. Verify RLS policies are enabled
3. Ensure user has tenant membership
4. Check network connectivity
