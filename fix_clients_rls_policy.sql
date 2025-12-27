-- Add missing INSERT policy for public.clients table
-- This allows authenticated users to create their own client organization during registration

CREATE POLICY "Users can create their own client" 
ON "public"."clients" 
FOR INSERT 
TO "authenticated" 
WITH CHECK ("owner_id" = "auth"."uid"());

-- Verify the policy was created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'clients' 
ORDER BY policyname;
