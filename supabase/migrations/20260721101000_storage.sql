-- =====================================================================
-- Stockage des documents (factures + relevés source)
-- Bucket privé. Convention de chemin : <company_id>/<type>/<fichier>
-- L'accès est cloisonné : on doit avoir accès à la société (1er segment).
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- Helper : 1er segment du chemin = company_id
create or replace function public.storage_company_id(objname text)
returns uuid language sql immutable as $$
  select nullif(split_part(objname, '/', 1), '')::uuid;
$$;

drop policy if exists documents_read on storage.objects;
create policy documents_read on storage.objects for select
  using (bucket_id = 'documents'
         and public.has_company_access(public.storage_company_id(name)));

drop policy if exists documents_insert on storage.objects;
create policy documents_insert on storage.objects for insert
  with check (bucket_id = 'documents'
              and public.has_company_access(public.storage_company_id(name)));

drop policy if exists documents_update on storage.objects;
create policy documents_update on storage.objects for update
  using (bucket_id = 'documents'
         and public.has_company_access(public.storage_company_id(name)));

drop policy if exists documents_delete on storage.objects;
create policy documents_delete on storage.objects for delete
  using (bucket_id = 'documents' and public.is_admin());
