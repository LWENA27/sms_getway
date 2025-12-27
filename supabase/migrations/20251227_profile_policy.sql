-- Allow users to manage their own profile rows in sms_gateway.users
-- Applies to select/insert/update/delete for authenticated users
create policy if not exists "Users can manage own profile" on "sms_gateway"."users"
for all
using (id = auth.uid())
with check (id = auth.uid());
