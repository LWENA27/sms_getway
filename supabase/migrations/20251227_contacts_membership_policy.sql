-- Enforce tenant membership for contacts operations
create policy if not exists "Tenant members manage contacts" on "sms_gateway"."contacts"
for all
using (
  user_id = auth.uid()
  and tenant_id in (
    select tenant_id from "sms_gateway"."tenant_members" where user_id = auth.uid()
  )
)
with check (
  user_id = auth.uid()
  and tenant_id in (
    select tenant_id from "sms_gateway"."tenant_members" where user_id = auth.uid()
  )
);
