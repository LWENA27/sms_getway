-- Allow users to manage their own contacts in sms_gateway.contacts
-- Applies to select/insert/update/delete for authenticated users
create policy if not exists "Users can manage own contacts" on "sms_gateway"."contacts"
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());
